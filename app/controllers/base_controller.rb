class BaseController < ApplicationController
  rescue_from ActiveRecord::RecordInvalid, with: :render_bad_request
  rescue_from ActiveRecord::RecordNotFound, with: :render_not_found
  rescue_from ActiveRecord::RecordNotUnique, with: :render_conflict

  private

  def success_response(record, status: :ok)
    render json: request_response(record), status: status
  end

  def request_response(record)
    {
      request_id: record.request_id,
      status: record.status,
      attempts: record.attempts,
      last_error: record.last_error,
      processed_at: record.processed_at,
      created_at: record.created_at,
      updated_at: record.updated_at
    }
  end

  def render_bad_request(exception)
    render json: { error: exception.record.errors.full_messages }, status: :bad_request
  end

  def render_conflict(_exception = nil, message: 'Duplicate request_id')
    render json: { error: message }, status: :conflict
  end

  def render_not_found(_exception = nil, message: 'Job request not found')
    render json: { error: message }, status: :not_found
  end

  def render_unprocessable_entity(message)
    render json: { error: message }, status: :unprocessable_entity
  end
end
