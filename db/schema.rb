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

ActiveRecord::Schema[8.1].define(version: 2026_08_07_120001) do
  create_table "collectible_labels", force: :cascade do |t|
    t.integer "collectible_id", null: false
    t.datetime "created_at", null: false
    t.integer "label_id", null: false
    t.datetime "updated_at", null: false
    t.index ["collectible_id", "label_id"], name: "index_collectible_labels_on_collectible_id_and_label_id", unique: true
    t.index ["collectible_id"], name: "index_collectible_labels_on_collectible_id"
    t.index ["label_id"], name: "index_collectible_labels_on_label_id"
  end

  create_table "collectibles", force: :cascade do |t|
    t.string "author"
    t.boolean "competitive", default: false, null: false
    t.boolean "completed", default: false, null: false
    t.boolean "cooperative", default: false, null: false
    t.datetime "created_at", null: false
    t.boolean "evergreen", default: false, null: false
    t.boolean "local_multiplayer", default: false, null: false
    t.integer "max_players"
    t.integer "min_players"
    t.text "notes"
    t.boolean "online_multiplayer", default: false, null: false
    t.string "system"
    t.string "title", null: false
    t.string "type", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["title"], name: "index_collectibles_on_title"
    t.index ["type"], name: "index_collectibles_on_type"
    t.index ["user_id"], name: "index_collectibles_on_user_id"
  end

  create_table "custom_sorts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.json "criteria", default: [], null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_custom_sorts_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_custom_sorts_on_user_id"
  end

  create_table "follows", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "followed_id", null: false
    t.integer "follower_id", null: false
    t.datetime "updated_at", null: false
    t.index ["followed_id"], name: "index_follows_on_followed_id"
    t.index ["follower_id", "followed_id"], name: "index_follows_on_follower_id_and_followed_id", unique: true
    t.index ["follower_id"], name: "index_follows_on_follower_id"
  end

  create_table "labels", force: :cascade do |t|
    t.json "collectible_types", default: [], null: false
    t.string "colour", default: "blue", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["user_id", "name"], name: "index_labels_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_labels_on_user_id"
  end

  create_table "profile_accesses", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "owner_id", null: false
    t.datetime "updated_at", null: false
    t.integer "viewer_id", null: false
    t.index ["owner_id", "viewer_id"], name: "index_profile_accesses_on_owner_id_and_viewer_id", unique: true
    t.index ["owner_id"], name: "index_profile_accesses_on_owner_id"
    t.index ["viewer_id"], name: "index_profile_accesses_on_viewer_id"
  end

  create_table "share_links", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.datetime "expires_at"
    t.string "token", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["token"], name: "index_share_links_on_token", unique: true
    t.index ["user_id"], name: "index_share_links_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "collectibles_sort", default: "updated", null: false
    t.datetime "collection_updated_at"
    t.string "collection_view", default: "cards", null: false
    t.string "collections_sort", default: "recent", null: false
    t.integer "consumed_timestep"
    t.datetime "created_at", null: false
    t.string "display_name"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.json "hidden_default_sorts", default: [], null: false
    t.json "hidden_link_keys", default: [], null: false
    t.boolean "hide_links_on_others", default: false, null: false
    t.boolean "otp_required_for_login", default: true
    t.string "otp_secret"
    t.boolean "public_profile", default: true, null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "theme", default: "light", null: false
    t.datetime "updated_at", null: false
    t.string "username"
    t.index ["collection_updated_at"], name: "index_users_on_collection_updated_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["public_profile"], name: "index_users_on_public_profile"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["username"], name: "index_users_on_username", unique: true
  end

  add_foreign_key "collectible_labels", "collectibles"
  add_foreign_key "collectible_labels", "labels"
  add_foreign_key "collectibles", "users"
  add_foreign_key "custom_sorts", "users"
  add_foreign_key "follows", "users", column: "followed_id"
  add_foreign_key "follows", "users", column: "follower_id"
  add_foreign_key "labels", "users"
  add_foreign_key "profile_accesses", "users", column: "owner_id"
  add_foreign_key "profile_accesses", "users", column: "viewer_id"
  add_foreign_key "share_links", "users"
end
