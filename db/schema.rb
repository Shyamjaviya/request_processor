# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2026_03_30_130000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "job_requests", force: :cascade do |t|
    t.string "request_id", null: false
    t.jsonb "payload", default: {}, null: false
    t.integer "status", default: 0, null: false
    t.integer "attempts", default: 0, null: false
    t.text "last_error"
    t.datetime "locked_at"
    t.datetime "processing_started_at"
    t.datetime "processed_at"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["request_id"], name: "index_job_requests_on_request_id", unique: true
    t.index ["status"], name: "index_job_requests_on_status"
  end

end
