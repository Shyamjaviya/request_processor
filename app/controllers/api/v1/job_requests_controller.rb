class Api::V1::JobRequestsController < BaseController
  def create
    request_id = job_request_params[:request_id]
    payload = job_request_params[:payload]

    record = JobRequest.find_by(request_id: request_id)
    if record.present?
      if record.completed? || record.processing? || record.pending?
        return render_conflict(message: "Cannot create request in status #{record.status}")
      end

      if record.failed?
        # allow requeue for transient failure
        record.update!(status: :pending) if record.attempts < JobRequest::MAX_ATTEMPTS
      end
    else
      record = JobRequest.create!(request_id: request_id, payload: payload, status: :pending)
    end

    ProcessJobRequestJob.perform_later(record.request_id)
    success_response(record, status: :accepted)
  end

  def show
    record = JobRequest.find_by!(request_id: params[:id])
    success_response(record)
  end

  def cancel
    record = JobRequest.find_by!(request_id: params[:id])

    if record.cancelled? || record.completed?
      return render_unprocessable_entity("Cannot cancel status #{record.status}")
    end

    record.cancel!
    success_response(record)
  end

  private

  def job_request_params
    params.require(:job_request).permit(:request_id, payload: {})
  end
end