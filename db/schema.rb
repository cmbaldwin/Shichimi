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

ActiveRecord::Schema[8.1].define(version: 2026_11_06_010000) do
  create_table "push_subscriptions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "endpoint", null: false
    t.string "p256dh_key", null: false
    t.string "auth_key", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["endpoint"], name: "index_push_subscriptions_on_endpoint", unique: true
    t.index ["user_id"], name: "index_push_subscriptions_on_user_id"
  end

  create_table "routine_items", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "workout_id", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "workout_id"], name: "index_routine_items_on_user_id_and_workout_id", unique: true
    t.index ["user_id"], name: "index_routine_items_on_user_id"
    t.index ["workout_id"], name: "index_routine_items_on_workout_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "uchujin_check_ins", force: :cascade do |t|
    t.string "name", null: false
    t.integer "expected_every_seconds"
    t.datetime "last_seen_at"
    t.integer "ping_count", default: 0, null: false
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_uchujin_check_ins_on_name", unique: true
  end

  create_table "uchujin_comments", force: :cascade do |t|
    t.integer "fault_id", null: false
    t.text "body", null: false
    t.bigint "author_id"
    t.string "author_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fault_id"], name: "index_uchujin_comments_on_fault_id"
  end

  create_table "uchujin_deployments", force: :cascade do |t|
    t.string "sha", null: false
    t.string "environment", null: false
    t.datetime "deployed_at", null: false
    t.string "repository"
    t.string "user"
    t.json "metadata", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["environment", "deployed_at"], name: "index_uchujin_deployments_on_environment_and_deployed_at"
  end

  create_table "uchujin_faults", force: :cascade do |t|
    t.string "fingerprint", null: false
    t.string "class_name", null: false
    t.text "message"
    t.string "component", default: "web", null: false
    t.string "environment", null: false
    t.string "status", default: "unresolved", null: false
    t.integer "occurrences_count", default: 0, null: false
    t.datetime "first_seen_at"
    t.datetime "last_seen_at"
    t.datetime "resolved_at"
    t.datetime "last_notified_at"
    t.bigint "assignee_id"
    t.string "revision"
    t.json "tags", default: []
    t.json "sample_context", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["class_name"], name: "index_uchujin_faults_on_class_name"
    t.index ["component"], name: "index_uchujin_faults_on_component"
    t.index ["environment"], name: "index_uchujin_faults_on_environment"
    t.index ["fingerprint"], name: "index_uchujin_faults_on_fingerprint", unique: true
    t.index ["last_seen_at"], name: "index_uchujin_faults_on_last_seen_at"
    t.index ["status"], name: "index_uchujin_faults_on_status"
  end

  create_table "uchujin_notifications", force: :cascade do |t|
    t.integer "fault_id"
    t.string "channel", null: false
    t.string "status", default: "sent"
    t.json "payload", default: {}
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fault_id"], name: "index_uchujin_notifications_on_fault_id"
  end

  create_table "uchujin_occurrences", force: :cascade do |t|
    t.integer "fault_id", null: false
    t.datetime "occurred_at", null: false
    t.text "message"
    t.json "backtrace", default: []
    t.json "backtrace_app", default: []
    t.json "source_context_lines", default: []
    t.json "cause"
    t.json "context", default: {}
    t.json "breadcrumbs", default: []
    t.json "server_stats", default: {}
    t.json "params", default: {}
    t.json "request_metadata", default: {}
    t.json "client_info", default: {}
    t.string "component"
    t.string "environment"
    t.string "revision"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["fault_id"], name: "index_uchujin_occurrences_on_fault_id"
    t.index ["occurred_at"], name: "index_uchujin_occurrences_on_occurred_at"
  end

  create_table "uchujin_uptime_checks", force: :cascade do |t|
    t.string "url", null: false
    t.string "status", default: "unknown", null: false
    t.integer "response_time_ms"
    t.integer "status_code"
    t.text "error_message"
    t.datetime "checked_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["url", "checked_at"], name: "index_uchujin_uptime_checks_on_url_and_checked_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name"
    t.string "time_zone", default: "Asia/Tokyo", null: false
    t.decimal "weight_kg", precision: 5, scale: 1
    t.integer "weekly_goal", default: 5, null: false
    t.boolean "reminders_enabled", default: false, null: false
    t.string "reminder_time", default: "07:00", null: false
    t.string "reminder_days", default: "0123456", null: false
    t.date "last_reminded_on"
    t.boolean "voice_enabled", default: true, null: false
    t.boolean "admin", default: false, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  create_table "workout_logs", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "workout_id"
    t.string "workout_name", null: false
    t.string "format", null: false
    t.integer "work_seconds", null: false
    t.integer "rest_seconds", null: false
    t.json "completed_slugs", default: [], null: false
    t.integer "duration_seconds", default: 0, null: false
    t.datetime "performed_at", null: false
    t.integer "rpe"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "performed_at"], name: "index_workout_logs_on_user_id_and_performed_at"
    t.index ["user_id"], name: "index_workout_logs_on_user_id"
    t.index ["workout_id"], name: "index_workout_logs_on_workout_id"
  end

  create_table "workouts", force: :cascade do |t|
    t.integer "user_id"
    t.string "name", null: false
    t.string "slug"
    t.string "format", null: false
    t.json "exercise_slugs", default: [], null: false
    t.integer "level", default: 2, null: false
    t.string "focus", default: "full", null: false
    t.text "about"
    t.boolean "low_impact", default: false, null: false
    t.boolean "needs_floor", default: true, null: false
    t.string "equipment", default: "", null: false
    t.integer "total_seconds", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["format", "focus", "level"], name: "index_workouts_on_format_and_focus_and_level"
    t.index ["slug"], name: "index_workouts_on_slug", unique: true
    t.index ["user_id"], name: "index_workouts_on_user_id"
  end

  add_foreign_key "push_subscriptions", "users"
  add_foreign_key "routine_items", "users"
  add_foreign_key "routine_items", "workouts"
  add_foreign_key "sessions", "users"
  add_foreign_key "uchujin_comments", "uchujin_faults", column: "fault_id"
  add_foreign_key "uchujin_notifications", "uchujin_faults", column: "fault_id"
  add_foreign_key "uchujin_occurrences", "uchujin_faults", column: "fault_id"
  add_foreign_key "workout_logs", "users"
  add_foreign_key "workout_logs", "workouts", on_delete: :nullify
  add_foreign_key "workouts", "users"
end
