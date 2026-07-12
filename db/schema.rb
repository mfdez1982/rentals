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

ActiveRecord::Schema[8.1].define(version: 2026_07_09_000001) do
  create_table "expenses", force: :cascade do |t|
    t.decimal "amount", precision: 10, scale: 2, null: false
    t.integer "category", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "description"
    t.string "invoice_url"
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

  create_table "rental_agreements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "end_date", null: false
    t.bigint "property_id", null: false
    t.decimal "rent_amount", precision: 10, scale: 2, null: false
    t.date "start_date", null: false
    t.datetime "updated_at", null: false
    t.index ["property_id"], name: "index_rental_agreements_on_property_id"
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

  add_foreign_key "expenses", "properties"
  add_foreign_key "landlords", "users"
  add_foreign_key "notes", "landlords"
  add_foreign_key "payments", "rental_agreements"
  add_foreign_key "properties", "landlords"
  add_foreign_key "rental_agreements", "properties"
end
