# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `rails
# db:schema:load`. When creating a new database, `rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2019_08_28_183826) do

  create_table "affiliates", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.string "name"
    t.string "title"
    t.string "image_uid"
    t.string "website"
    t.string "twitch"
    t.string "twitter"
    t.string "facebook"
    t.string "instagram"
    t.string "youtube"
    t.text "bio"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

  create_table "pledges", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "email"
    t.string "twitch_display_name"
    t.integer "twitch_id"
    t.datetime "signed_on"
    t.boolean "badge_revoked", default: false
    t.datetime "revoked_on"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "twitch_email"
    t.string "identifier"
    t.datetime "twitch_authed_on"
  end

  create_table "stories", options: "ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_520_ci", force: :cascade do |t|
    t.string "headline"
    t.text "description"
    t.string "image_uid"
    t.string "link"
    t.datetime "created_at", precision: 6, null: false
    t.datetime "updated_at", precision: 6, null: false
  end

end
