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

ActiveRecord::Schema[8.1].define(version: 2026_09_18_191524) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.decimal "balance_at_creation", precision: 20, scale: 4
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.datetime "deleted_at"
    t.decimal "initial_balance", precision: 20, scale: 4
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["code"], name: "index_accounts_on_code", unique: true
    t.index ["deleted_at"], name: "index_accounts_on_deleted_at"
    t.index ["user_id"], name: "index_accounts_on_user_id"
  end

  create_table "currency_rates", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "left", null: false
    t.decimal "rate", precision: 20, scale: 8, null: false
    t.string "right", null: false
    t.datetime "updated_at", null: false
    t.index ["left", "right"], name: "index_currency_rates_on_left_and_right", unique: true
  end

  create_table "transactions", force: :cascade do |t|
    t.bigint "account_id", null: false
    t.decimal "amount", precision: 20, scale: 4, null: false
    t.string "category"
    t.string "code", null: false
    t.bigint "counterparty_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", null: false
    t.string "dedup_hash", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.datetime "occurred_at", null: false
    t.string "payment_method", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id", "occurred_at"], name: "index_transactions_on_account_id_and_occurred_at"
    t.index ["account_id"], name: "index_transactions_on_account_id"
    t.index ["code"], name: "index_transactions_on_code", unique: true
    t.index ["counterparty_id"], name: "index_transactions_on_counterparty_id"
    t.index ["dedup_hash"], name: "index_transactions_on_dedup_hash"
    t.index ["deleted_at"], name: "index_transactions_on_deleted_at"
  end

  create_table "users", force: :cascade do |t|
    t.string "code", null: false
    t.string "company_name"
    t.datetime "created_at", null: false
    t.string "currency"
    t.string "email"
    t.string "first_name"
    t.string "image"
    t.string "last_name"
    t.string "password_digest"
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_users_on_code", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  add_foreign_key "accounts", "users"
  add_foreign_key "transactions", "accounts"
  add_foreign_key "transactions", "users", column: "counterparty_id"
end
