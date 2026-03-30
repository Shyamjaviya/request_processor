class JobRequest < ApplicationRecord
  enum status: { pending: 0, processing: 1, completed: 2, failed: 3, cancelled: 4 }

  validates :request_id, presence: true, uniqueness: { case_sensitive: false }
  validates :payload, presence: true

  scope :ready_to_process, -> { pending.or(failed).where('attempts < ?', MAX_ATTEMPTS) }

  MAX_ATTEMPTS = 5

  def mark_processing!
    transaction do
      lock! # row-level lock
      return false if cancelled? || completed?

      update!(status: :processing, processing_started_at: Time.current, locked_at: Time.current, attempts: attempts + 1)
    end
    true
  end

  def mark_completed!
    update!(status: :completed, processed_at: Time.current, last_error: nil)
  end

  def mark_failed!(exception)
    update!(status: :failed, last_error: exception.to_s)
  end

  def cancel!
    update!(status: :cancelled, cancelled_at: Time.current)
  end
end