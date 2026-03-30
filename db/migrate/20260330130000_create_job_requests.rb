class CreateJobRequests < ActiveRecord::Migration[7.0]
  def change
    create_table :job_requests do |t|
      t.string :request_id, null: false
      t.jsonb :payload, null: false, default: {}
      t.integer :status, null: false, default: 0
      t.integer :attempts, null: false, default: 0
      t.text :last_error
      t.datetime :locked_at
      t.datetime :processing_started_at
      t.datetime :processed_at
      t.datetime :cancelled_at

      t.timestamps
    end

    add_index :job_requests, :request_id, unique: true
    add_index :job_requests, :status
  end
end