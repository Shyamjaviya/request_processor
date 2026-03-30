class ProcessJobRequestJob < ApplicationJob
  queue_as :default

  retry_on StandardError, wait: :exponentially_longer, attempts: JobRequest::MAX_ATTEMPTS

  def perform(request_id)
    request = JobRequest.find_by!(request_id: request_id)

    return if request.cancelled? || request.completed?

    unless request.mark_processing!
      Rails.logger.info("JobRequest[#{request_id}] no-op: already #{request.status}")
      return
    end

    Rails.logger.info("JobRequest[#{request_id}] processing start, attempt #{request.attempts}")

    begin
      # Simulate real work (replace with actual business logic)
      simulate_work(request.payload)

      request.mark_completed!

      Rails.logger.info("JobRequest[#{request_id}] completed")
    rescue StandardError => e
      request.mark_failed!(e)
      Rails.logger.error("JobRequest[#{request_id}] failed: #{e.class}: #{e.message}")

      raise if request.attempts < JobRequest::MAX_ATTEMPTS

      Rails.logger.error("JobRequest[#{request_id}] reached max attempts and will not retry")
    end
  end

  private

  def simulate_work(payload)
    # Example of downstream call with transient failure possibility
    if payload.dig('fail') == true
      raise RuntimeError, 'Simulated external failure'
    end

    sleep(0.2) if payload.dig('slow') == true

    Rails.logger.info("simulate_work payload=#{payload.inspect}")
    true
  end
end