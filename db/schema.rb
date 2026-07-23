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

ActiveRecord::Schema[8.1].define(version: 2026_07_23_140854) do
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

  create_table "landlords", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "phone"
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
    t.date "paid_date"
    t.bigint "rental_agreement_id", null: false
    t.datetime "updated_at", null: false
    t.index ["rental_agreement_id"], name: "index_payments_on_rental_agreement_id"
  end

  create_table "properties", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "landlord_id", null: false
    t.string "name", null: false
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

  create_table "tax_reports", force: :cascade do |t|
    t.integer "active_rental_days", null: false
    t.datetime "created_at", null: false
    t.json "expense_lines", default: [], null: false
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
  add_foreign_key "tax_reports", "properties"
end
