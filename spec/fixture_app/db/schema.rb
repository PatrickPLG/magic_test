ActiveRecord::Schema[7.0].define(version: 2026_09_24_000001) do
  create_table "users", force: :cascade do |t|
    t.string "email", null: false, default: ""
    t.string "encrypted_password", null: false, default: ""
    t.string "authentication_token"
    t.string "role_type"
    t.integer "role_id"
    t.boolean "onboarded", null: false, default: false
    t.datetime "remember_created_at"
    t.timestamps
  end
  add_index "users", ["email"], unique: true
  add_index "users", %w[role_type role_id]

  create_table "students", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.date "birthday"
    t.string "gender"
    t.boolean "newsletter", default: false
    t.string "country", default: "DK"
    t.text "bio"
    t.boolean "automatic_verified", default: false
    t.timestamps
  end

  create_table "providers", force: :cascade do |t|
    t.string "name"
    t.string "registration_number"
    t.timestamps
  end

  create_table "institutions", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.boolean "allow_events", default: false
    t.timestamps
  end

  create_table "institutions_employees", force: :cascade do |t|
    t.integer "institution_id", null: false
    t.string "name"
    t.string "employee_type", null: false, default: "employee"
    t.timestamps
  end

  create_table "admins", force: :cascade do |t|
    t.string "name"
    t.timestamps
  end

  create_table "companies", force: :cascade do |t|
    t.string "name"
    t.string "cvr", null: false
    t.timestamps
  end

  create_table "team_members", force: :cascade do |t|
    t.string "name"
    t.string "department"
    t.timestamps
  end

  create_table "notes", force: :cascade do |t|
    t.string "notable_type", null: false
    t.integer "notable_id", null: false
    t.integer "author_id"
    t.text "body"
    t.timestamps
  end

  create_table "institutions_student_organisations", force: :cascade do |t|
    t.string "name"
    t.timestamps
  end

  create_table "student_organisation_memberships", force: :cascade do |t|
    t.integer "student_organisation_id", null: false
    t.string "name"
    t.string "email"
    t.string "membership_type", default: "member"
    t.timestamps
  end

  create_table "specialities", force: :cascade do |t|
    t.integer "institution_id"
    t.string "name"
    t.timestamps
  end

  create_table "categories", force: :cascade do |t|
    t.string "name"
    t.timestamps
  end

  create_table "events_events", force: :cascade do |t|
    t.integer "institution_id", null: false
    t.integer "category_id"
    t.string "name"
    t.text "description"
    t.boolean "terms_accepted", default: false
    t.string "account_number"
    t.string "registration_number"
    t.datetime "starts_at"
    t.string "location"
    t.boolean "published", default: false
    t.timestamps
  end

  create_table "events_ticket_types", force: :cascade do |t|
    t.integer "event_id", null: false
    t.string "name"
    t.integer "price", default: 0
    t.timestamps
  end

  create_table "discounts", force: :cascade do |t|
    t.integer "provider_id", null: false
    t.string "name_da"
    t.string "name_en"
    t.text "description"
    t.string "status", default: "draft"
    t.string "cover_image"
    t.boolean "archived", default: false
    t.integer "reminders_sent", default: 0
    t.timestamps
  end

  create_table "categories_discounts", id: false, force: :cascade do |t|
    t.integer "category_id", null: false
    t.integer "discount_id", null: false
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "provider_id", null: false
    t.string "number"
    t.integer "amount_cents", default: 0
    t.timestamps
  end

  create_table "leads", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "status", default: "new"
    t.integer "priority", null: false, default: 1
    t.text "note"
    t.timestamps
  end

  create_table "user_messages", force: :cascade do |t|
    t.integer "user_id", null: false
    t.text "body"
    t.timestamps
  end
end
