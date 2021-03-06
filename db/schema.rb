# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20161220213712) do

  create_table "batches", force: :cascade do |t|
    t.string   "event_id",                        null: false
    t.string   "number",                          null: false
    t.string   "location"
    t.string   "description",                     null: false
    t.string   "batch_type",                      null: false
    t.datetime "created_at",                      null: false
    t.datetime "updated_at",                      null: false
    t.string   "processing_status", default: "1", null: false
  end

  create_table "crm_campaigns", force: :cascade do |t|
    t.string   "event_id",         null: false
    t.string   "code",             null: false
    t.string   "name",             null: false
    t.datetime "created_at",       null: false
    t.datetime "updated_at",       null: false
    t.date     "event_start_date"
    t.date     "event_end_date"
    t.string   "campaign_id"
  end

  create_table "delayed_jobs", force: :cascade do |t|
    t.integer  "priority",   default: 0, null: false
    t.integer  "attempts",   default: 0, null: false
    t.text     "handler",                null: false
    t.text     "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string   "locked_by"
    t.string   "queue"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["priority", "run_at"], name: "delayed_jobs_priority"
  end

  create_table "events", force: :cascade do |t|
    t.string   "name",                                null: false
    t.boolean  "multiple_locations",                  null: false
    t.string   "qr_code_email_subject",               null: false
    t.string   "status",                default: "1", null: false
    t.datetime "created_at",                          null: false
    t.datetime "updated_at",                          null: false
  end

  create_table "locations", force: :cascade do |t|
    t.string   "name",       null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "on_site_attendees", force: :cascade do |t|
    t.string   "event_id",       null: false
    t.string   "first_name",     null: false
    t.string   "last_name",      null: false
    t.string   "account_name",   null: false
    t.string   "account_number"
    t.string   "street1",        null: false
    t.string   "street2"
    t.string   "city",           null: false
    t.string   "state",          null: false
    t.string   "zip_code",       null: false
    t.string   "email",          null: false
    t.string   "phone",          null: false
    t.string   "salesrep"
    t.string   "badge_type",     null: false
    t.boolean  "contact_in_crm"
    t.datetime "created_at",     null: false
    t.datetime "updated_at",     null: false
    t.string   "activity_id"
  end

  create_table "types", force: :cascade do |t|
    t.string   "name",               null: false
    t.boolean  "multiple_locations", null: false
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

end
