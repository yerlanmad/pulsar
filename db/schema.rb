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

ActiveRecord::Schema[8.1].define(version: 2026_03_11_065713) do
  create_table "agents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "sip_account", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["sip_account"], name: "index_agents_on_sip_account", unique: true
    t.index ["user_id"], name: "index_agents_on_user_id"
  end

  create_table "call_records", force: :cascade do |t|
    t.integer "agent_id"
    t.datetime "answered_at"
    t.string "caller_number"
    t.datetime "created_at", null: false
    t.string "destination_number"
    t.integer "duration"
    t.datetime "ended_at"
    t.integer "queue_config_id"
    t.datetime "started_at"
    t.integer "status", default: 0, null: false
    t.string "uniqueid"
    t.datetime "updated_at", null: false
    t.integer "wait_time"
    t.index ["agent_id"], name: "index_call_records_on_agent_id"
    t.index ["queue_config_id"], name: "index_call_records_on_queue_config_id"
    t.index ["started_at"], name: "index_call_records_on_started_at"
    t.index ["uniqueid"], name: "index_call_records_on_uniqueid", unique: true
  end

  create_table "queue_configs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "max_wait_time", default: 300, null: false
    t.string "name", null: false
    t.integer "strategy", default: 0, null: false
    t.integer "timeout", default: 30, null: false
    t.integer "timeout_action", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_queue_configs_on_name", unique: true
  end

  create_table "queue_memberships", force: :cascade do |t|
    t.integer "agent_id", null: false
    t.datetime "created_at", null: false
    t.integer "priority", default: 0, null: false
    t.integer "queue_config_id", null: false
    t.datetime "updated_at", null: false
    t.index ["agent_id", "queue_config_id"], name: "index_queue_memberships_on_agent_id_and_queue_config_id", unique: true
    t.index ["agent_id"], name: "index_queue_memberships_on_agent_id"
    t.index ["queue_config_id"], name: "index_queue_memberships_on_queue_config_id"
  end

  create_table "recordings", force: :cascade do |t|
    t.integer "call_record_id", null: false
    t.datetime "created_at", null: false
    t.integer "duration"
    t.string "file_path"
    t.integer "file_size"
    t.datetime "updated_at", null: false
    t.index ["call_record_id"], name: "index_recordings_on_call_record_id"
  end

  create_table "route_rules", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "pattern", null: false
    t.integer "position", default: 0, null: false
    t.integer "queue_config_id", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_route_rules_on_position"
    t.index ["queue_config_id"], name: "index_route_rules_on_queue_config_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", default: "", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "agents", "users"
  add_foreign_key "call_records", "agents"
  add_foreign_key "call_records", "queue_configs"
  add_foreign_key "queue_memberships", "agents"
  add_foreign_key "queue_memberships", "queue_configs"
  add_foreign_key "recordings", "call_records"
  add_foreign_key "route_rules", "queue_configs"
  add_foreign_key "sessions", "users"
end
