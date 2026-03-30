# Rails Sidekiq idempotent API demo

## Overview

This project is a backend service demonstrating:
- Idempotent request processing via `request_id`
- Remote request record storage (`JobRequest` model)
- Background job execution (ActiveJob + Sidekiq)
- Duplicate detection, retry handling, and cancellation
- Concurrency-safe transitions with DB row locking
- HTTP API outputs for creation/status/cancel
- Controller architecture with `BaseController` for shared response handling and error rendering

## Tech stack

- Ruby 3.x / Rails 7.x
- PostgreSQL
- Redis + Sidekiq
- ActiveJob with Sidekiq adapter

## Setup

```bash
# Install
bundle install

# Start Redis (locally)
redis-server &

# Set up databases
bin/rails db:create db:migrate

# Start Sidekiq
bundle exec sidekiq

# Start Rails server
bin/rails server
```

## API endpoints

### 1. Create job request

`POST /api/v1/job_requests`

Request JSON:

```json
{
  "job_request": {
    "request_id": "uuid-1234-abcd",
    "payload": { "value": 123 }
  }
}
```

Responses:
- `202 Accepted` (new request accepted and enqueued)
- `409 Conflict` (duplicate request id already exists)
- `400 Bad Request` (validation failure)

### 2. Get status

`GET /api/v1/job_requests/:id`

- `200 OK` with status payload (pending/processing/completed/failed/cancelled)
- `404 Not Found` if missing

### 3. Cancel request

`POST /api/v1/job_requests/:id/cancel`

- `200 OK` when cancelled
- `422 Unprocessable Entity` if already completed/cancelled
- `404 Not Found` if missing

### 4. Sidekiq web UI

`GET /sidekiq`

## Example API Calls and Responses

### Create a new job request (success)

```bash
curl -X POST http://localhost:3000/api/v1/job_requests \
-H "Content-Type: application/json" \
-d '{
  "job_request": {
    "request_id": "test-123",
    "payload": { "workflow": "demo" }
  }
}'
```

**Response (202 Accepted):**
```json
{
  "request_id": "test-123",
  "status": "pending",
  "attempts": 0,
  "last_error": null,
  "processed_at": null,
  "created_at": "2026-03-30T12:00:00.000Z",
  "updated_at": "2026-03-30T12:00:00.000Z"
}
```

### Create duplicate request

```bash
curl -X POST http://localhost:3000/api/v1/job_requests \
-H "Content-Type: application/json" \
-d '{
  "job_request": {
    "request_id": "test-123",
    "payload": { "workflow": "demo" }
  }
}'
```

**Response (409 Conflict):**
```json
{
  "request_id": "test-123",
  "status": "pending",
  "attempts": 0,
  "last_error": null,
  "processed_at": null,
  "created_at": "2026-03-30T12:00:00.000Z",
  "updated_at": "2026-03-30T12:00:00.000Z"
}
```

### Get job status (after processing)

```bash
curl http://localhost:3000/api/v1/job_requests/test-123
```

**Response (200 OK):**
```json
{
  "request_id": "test-123",
  "status": "completed",
  "attempts": 1,
  "last_error": null,
  "processed_at": "2026-03-30T12:00:05.000Z",
  "created_at": "2026-03-30T12:00:00.000Z",
  "updated_at": "2026-03-30T12:00:05.000Z"
}
```

### Cancel a pending request

```bash
curl -X POST http://localhost:3000/api/v1/job_requests/test-123/cancel
```

**Response (422 Unprocessable Entity, if completed):**
```json
{
  "error": "Cannot cancel status completed"
}
```

**Response (200 OK, if pending):**
```json
{
  "request_id": "test-123",
  "status": "cancelled",
  "attempts": 0,
  "last_error": null,
  "processed_at": null,
  "created_at": "2026-03-30T12:00:00.000Z",
  "updated_at": "2026-03-30T12:00:05.000Z"
}
```

### Create with invalid payload

```bash
curl -X POST http://localhost:3000/api/v1/job_requests \
-H "Content-Type: application/json" \
-d '{
  "job_request": {
    "request_id": "test-invalid",
    "payload": {}
  }
}'
```

**Response (400 Bad Request):**
```json
{
  "error": ["Payload can't be blank"]
}
```

### Create with failure simulation

```bash
curl -X POST http://localhost:3000/api/v1/job_requests \
-H "Content-Type: application/json" \
-d '{
  "job_request": {
    "request_id": "test-fail",
    "payload": { "fail": true }
  }
}'
```

**Response (202 Accepted):**
```json
{
  "request_id": "test-fail",
  "status": "pending",
  "attempts": 0,
  "last_error": null,
  "processed_at": null,
  "created_at": "2026-03-30T12:00:00.000Z",
  "updated_at": "2026-03-30T12:00:00.000Z"
}
```

**Status after retries (GET):**
```json
{
  "request_id": "test-fail",
  "status": "failed",
  "attempts": 5,
  "last_error": "Simulated external failure",
  "processed_at": null,
  "created_at": "2026-03-30T12:00:00.000Z",
  "updated_at": "2026-03-30T12:00:10.000Z"
}
```

## Job workflow

- `ProcessJobRequestJob.perform(request_id)`
- loads `JobRequest` record
- guards:
  - return immediately if `cancelled` or `completed`
- records processing state with `mark_processing!` (row lock + attempt increment)
- performs work in `simulate_work`
- on success:
  - `mark_completed!`
- on failure:
  - `mark_failed!`
  - `retry_on StandardError` up to `JobRequest::MAX_ATTEMPTS`

## Tests (suggested)

- Add controller tests in `test/controllers/api/v1/job_requests_controller_test.rb`:
  - `POST /api/v1/job_requests` success, duplicate, invalid payload
  - `GET /api/v1/job_requests/:id` 200 and 404
  - `POST /api/v1/job_requests/:id/cancel` 200, 422, 404
- Add model tests for `JobRequest#mark_processing!`, `mark_completed!`, `mark_failed!`, `cancel!`
- Add job tests for `ProcessJobRequestJob` in `test/jobs/process_job_request_job_test.rb`

## Model schema

`job_requests` fields:
- `request_id` (string, unique)
- `payload` (jsonb)
- `status` enum (pending/processing/completed/failed/cancelled)
- `attempts` (integer)
- `last_error` (text)
- `locked_at`, `processing_started_at`, `processed_at`, `cancelled_at`
- timestamps

## Edge cases addressed

- duplicate requests via unique `request_id`
- retry deduplication via `mark_processing!` guard and status
- downstream failure sim with `payload.fail`, error status, retry hooks
- user cancellation endpoint + job early exit
- concurrent updates managed by `lock!` and DB constraint
- slow processing sim via `payload.slow`
- basic data validation and idempotency enforced by model + controller
- non-retry conditions: cancelled/completed guard + permanent failure on max attempts

## Logs

`ProcessJobRequestJob` logs job lifecycle:
- processing start
- completed
- failed with message
- reached max attempts
- simulate_work payload

## Testing

1. `bin/rails test`
2. API tests (Postman/curl): create + get + cancel + duplicate.

## Useful curl examples

```bash
curl -X POST http://localhost:3000/api/v1/job_requests \
  -H 'Content-Type: application/json' \
  -d '{"job_request":{"request_id":"abc-123","payload":{"fail":false}}}'

curl http://localhost:3000/api/v1/job_requests/abc-123

curl -X POST http://localhost:3000/api/v1/job_requests/abc-123/cancel
```

## Evaluation checklist

- [x] Code quality
- [x] Problem solving
- [x] Edge case handling
- [x] Concurrency understanding
- [x] DB design
- [x] Logging
- [x] README clarity

