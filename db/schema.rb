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

ActiveRecord::Schema[8.1].define(version: 2026_07_26_130000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agreement_tenants", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "invitation_token", null: false
    t.datetime "invited_at", null: false
    t.string "invited_email", null: false
    t.datetime "landlord_acknowledged_at"
    t.integer "rental_agreement_id", null: false
    t.datetime "responded_at"
    t.integer "status", default: 0, null: false
    t.datetime "tenant_acknowledged_at"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["invitation_token"], name: "index_agreement_tenants_on_invitation_token", unique: true
    t.index ["rental_agreement_id", "invited_email"], name: "index_agreement_tenants_live_unique", unique: true, where: "status IN (0,1)"
    t.index ["rental_agreement_id"], name: "index_agreement_tenants_on_rental_agreement_id"
    t.index ["user_id"], name: "index_agreement_tenants_on_user_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.integer "category", null: false
    t.boolean "collectable", default: false, null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.boolean "deductible", default: true, null: false
    t.string "description"
    t.string "invoice_url"
    t.date "period_end"
    t.date "period_start"
    t.bigint "property_id", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_expenses_on_property_id"
  end

  create_table "flipper_features", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_flipper_features_on_key", unique: true
  end

  create_table "flipper_gates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "feature_key", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.text "value"
    t.index ["feature_key", "key", "value"], name: "index_flipper_gates_on_feature_key_and_key_and_value", unique: true
  end

  create_table "landlords", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "phone"
    t.integer "plan", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["user_id"], name: "index_landlords_on_user_id"
  end

  create_table "notes", force: :cascade do |t|
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.text "description", null: false
    t.date "due_date"
    t.bigint "landlord_id", null: false
    t.bigint "noteable_id"
    t.string "noteable_type"
    t.integer "status", default: 0, null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["due_date"], name: "index_notes_on_due_date"
    t.index ["landlord_id", "noteable_type", "noteable_id"], name: "index_notes_on_landlord_id_and_noteable_type_and_noteable_id"
    t.index ["landlord_id", "status"], name: "index_notes_on_landlord_id_and_status"
    t.index ["landlord_id"], name: "index_notes_on_landlord_id"
    t.index ["noteable_type", "noteable_id"], name: "index_notes_on_noteable"
  end

  create_table "payments", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.date "due_date", null: false
    t.datetime "last_reminded_at"
    t.date "paid_date"
    t.bigint "rental_agreement_id", null: false
    t.datetime "updated_at", null: false
    t.index ["rental_agreement_id"], name: "index_payments_on_rental_agreement_id"
  end

  create_table "properties", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "landlord_id", null: false
    t.string "name", null: false
    t.boolean "reminders_enabled", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["landlord_id"], name: "index_properties_on_landlord_id"
  end

  create_table "recollections", force: :cascade do |t|
    t.integer "agreement_tenant_id"
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.datetime "created_at", null: false
    t.date "due_date"
    t.integer "expense_id", null: false
    t.date "paid_date"
    t.date "period_end", null: false
    t.date "period_start", null: false
    t.integer "rental_agreement_id", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["agreement_tenant_id"], name: "index_recollections_on_agreement_tenant_id"
    t.index ["expense_id", "rental_agreement_id", "agreement_tenant_id"], name: "index_recollections_on_expense_agreement_tenant_unique", unique: true
    t.index ["expense_id", "rental_agreement_id"], name: "index_recollections_on_expense_agreement_no_payer_unique", unique: true, where: "agreement_tenant_id IS NULL"
    t.index ["expense_id"], name: "index_recollections_on_expense_id"
    t.index ["rental_agreement_id"], name: "index_recollections_on_rental_agreement_id"
  end

  create_table "rental_agreements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.bigint "property_id", null: false
    t.decimal "rent_amount", precision: 10, scale: 2, null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_rental_agreements_on_property_id"
  end

  create_table "solid_queue_blocked_executions", force: :cascade do |t|
    t.string "concurrency_key", null: false
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["concurrency_key", "priority", "job_id"], name: "index_solid_queue_blocked_executions_for_release"
    t.index ["expires_at", "concurrency_key"], name: "index_solid_queue_blocked_executions_for_maintenance"
    t.index ["job_id"], name: "index_solid_queue_blocked_executions_on_job_id", unique: true
  end

  create_table "solid_queue_claimed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.bigint "process_id"
    t.index ["job_id"], name: "index_solid_queue_claimed_executions_on_job_id", unique: true
    t.index ["process_id", "job_id"], name: "index_solid_queue_claimed_executions_on_process_id_and_job_id"
  end

  create_table "solid_queue_failed_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error"
    t.bigint "job_id", null: false
    t.index ["job_id"], name: "index_solid_queue_failed_executions_on_job_id", unique: true
  end

  create_table "solid_queue_jobs", force: :cascade do |t|
    t.string "active_job_id"
    t.text "arguments"
    t.string "class_name", null: false
    t.string "concurrency_key"
    t.datetime "created_at", null: false
    t.datetime "finished_at"
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at"
    t.datetime "updated_at", null: false
    t.index ["active_job_id"], name: "index_solid_queue_jobs_on_active_job_id"
    t.index ["class_name"], name: "index_solid_queue_jobs_on_class_name"
    t.index ["finished_at"], name: "index_solid_queue_jobs_on_finished_at"
    t.index ["queue_name", "finished_at"], name: "index_solid_queue_jobs_for_filtering"
    t.index ["scheduled_at", "finished_at"], name: "index_solid_queue_jobs_for_alerting"
  end

  create_table "solid_queue_pauses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "queue_name", null: false
    t.index ["queue_name"], name: "index_solid_queue_pauses_on_queue_name", unique: true
  end

  create_table "solid_queue_processes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "hostname"
    t.string "kind", null: false
    t.datetime "last_heartbeat_at", null: false
    t.text "metadata"
    t.string "name", null: false
    t.integer "pid", null: false
    t.bigint "supervisor_id"
    t.index ["last_heartbeat_at"], name: "index_solid_queue_processes_on_last_heartbeat_at"
    t.index ["name", "supervisor_id"], name: "index_solid_queue_processes_on_name_and_supervisor_id", unique: true
    t.index ["supervisor_id"], name: "index_solid_queue_processes_on_supervisor_id"
  end

  create_table "solid_queue_ready_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.index ["job_id"], name: "index_solid_queue_ready_executions_on_job_id", unique: true
    t.index ["priority", "job_id"], name: "index_solid_queue_poll_all"
    t.index ["queue_name", "priority", "job_id"], name: "index_solid_queue_poll_by_queue"
  end

  create_table "solid_queue_recurring_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.datetime "run_at", null: false
    t.string "task_key", null: false
    t.index ["job_id"], name: "index_solid_queue_recurring_executions_on_job_id", unique: true
    t.index ["task_key", "run_at"], name: "index_solid_queue_recurring_executions_on_task_key_and_run_at", unique: true
  end

  create_table "solid_queue_recurring_tasks", force: :cascade do |t|
    t.text "arguments"
    t.string "class_name"
    t.string "command", limit: 2048
    t.datetime "created_at", null: false
    t.text "description"
    t.string "key", null: false
    t.integer "priority", default: 0
    t.string "queue_name"
    t.string "schedule", null: false
    t.boolean "static", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_solid_queue_recurring_tasks_on_key", unique: true
    t.index ["static"], name: "index_solid_queue_recurring_tasks_on_static"
  end

  create_table "solid_queue_scheduled_executions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "job_id", null: false
    t.integer "priority", default: 0, null: false
    t.string "queue_name", null: false
    t.datetime "scheduled_at", null: false
    t.index ["job_id"], name: "index_solid_queue_scheduled_executions_on_job_id", unique: true
    t.index ["scheduled_at", "priority", "job_id"], name: "index_solid_queue_dispatch_all"
  end

  create_table "solid_queue_semaphores", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "key", null: false
    t.datetime "updated_at", null: false
    t.integer "value", default: 1, null: false
    t.index ["expires_at"], name: "index_solid_queue_semaphores_on_expires_at"
    t.index ["key", "value"], name: "index_solid_queue_semaphores_on_key_and_value"
    t.index ["key"], name: "index_solid_queue_semaphores_on_key", unique: true
  end

  create_table "tax_reports", force: :cascade do |t|
    t.integer "active_rental_days", null: false
    t.datetime "created_at", null: false
    t.json "expense_lines", default: [], null: false
    t.string "name"
    t.decimal "pro_rata_ratio", precision: 5, scale: 4, null: false
    t.integer "property_id", null: false
    t.integer "total_days", null: false
    t.decimal "total_gross_income", precision: 10, scale: 2, null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["property_id", "year"], name: "index_tax_reports_on_property_id_and_year"
    t.index ["property_id"], name: "index_tax_reports_on_property_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agreement_tenants", "rental_agreements"
  add_foreign_key "agreement_tenants", "users"
  add_foreign_key "expenses", "properties"
  add_foreign_key "landlords", "users"
  add_foreign_key "notes", "landlords"
  add_foreign_key "payments", "rental_agreements"
  add_foreign_key "properties", "landlords"
  add_foreign_key "recollections", "agreement_tenants"
  add_foreign_key "recollections", "expenses"
  add_foreign_key "recollections", "rental_agreements"
  add_foreign_key "rental_agreements", "properties"
  add_foreign_key "solid_queue_blocked_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_claimed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_failed_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_ready_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_recurring_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "solid_queue_scheduled_executions", "solid_queue_jobs", column: "job_id", on_delete: :cascade
  add_foreign_key "tax_reports", "properties"
end
