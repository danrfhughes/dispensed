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

ActiveRecord::Schema[8.1].define(version: 2026_03_10_233729) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "doses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "fhir_id"
    t.integer "medication_id", null: false
    t.string "notes"
    t.integer "schedule_id", null: false
    t.datetime "scheduled_for", null: false
    t.string "status", default: "pending", null: false
    t.datetime "taken_at"
    t.datetime "updated_at", null: false
    t.index ["medication_id", "scheduled_for"], name: "index_doses_on_medication_id_and_scheduled_for"
    t.index ["medication_id"], name: "index_doses_on_medication_id"
    t.index ["schedule_id"], name: "index_doses_on_schedule_id"
  end

  create_table "medications", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.integer "days_supply", default: 28, null: false
    t.string "dmd_code"
    t.string "dose"
    t.date "end_date"
    t.string "fhir_id"
    t.string "form"
    t.date "last_dispensed_on"
    t.string "name", null: false
    t.text "notes"
    t.integer "patient_profile_id", null: false
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.index ["patient_profile_id"], name: "index_medications_on_patient_profile_id"
  end

  create_table "patient_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date_of_birth"
    t.string "fhir_id"
    t.string "nhs_number"
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["nhs_number"], name: "index_patient_profiles_on_nhs_number", unique: true, where: "(nhs_number IS NOT NULL)"
    t.index ["user_id"], name: "index_patient_profiles_on_user_id", unique: true
  end

  create_table "schedules", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "days_of_week", default: "daily", null: false
    t.string "instructions"
    t.integer "medication_id", null: false
    t.time "time_of_day", null: false
    t.datetime "updated_at", null: false
    t.index ["medication_id"], name: "index_schedules_on_medication_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "role", default: "patient", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "doses", "medications"
  add_foreign_key "doses", "schedules"
  add_foreign_key "medications", "patient_profiles"
  add_foreign_key "patient_profiles", "users"
  add_foreign_key "schedules", "medications"
end
