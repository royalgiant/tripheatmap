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

ActiveRecord::Schema[7.1].define(version: 2025_11_21_220239) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"
  enable_extension "postgis"

  create_table "error_logs", force: :cascade do |t|
    t.string "context", null: false
    t.text "error_message", null: false
    t.string "error_code"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["context"], name: "index_error_logs_on_context"
    t.index ["created_at"], name: "index_error_logs_on_created_at"
  end

  create_table "neighborhood_places_stats", force: :cascade do |t|
    t.bigint "neighborhood_id", null: false
    t.integer "restaurant_count"
    t.integer "cafe_count"
    t.integer "bar_count"
    t.integer "total_amenities"
    t.decimal "vibrancy_index"
    t.datetime "last_updated"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "bars_vibrancy"
    t.decimal "restaurants_vibrancy"
    t.decimal "cafes_vibrancy"
    t.index ["neighborhood_id"], name: "index_neighborhood_places_stats_on_neighborhood_id"
  end

  create_table "neighborhoods", force: :cascade do |t|
    t.string "name", null: false
    t.string "city"
    t.string "county"
    t.string "state"
    t.string "geoid"
    t.integer "population"
    t.geography "geom", limit: {:srid=>4326, :type=>"geometry", :geographic=>true}
    t.geography "centroid", limit: {:srid=>4326, :type=>"st_point", :geographic=>true}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "wikipedia_image_url"
    t.datetime "wikipedia_image_checked_at"
    t.string "slug"
    t.string "country"
    t.string "continent"
    t.text "description"
    t.text "about"
    t.text "time_to_visit"
    t.text "getting_around"
    t.index ["centroid"], name: "index_neighborhoods_on_centroid", using: :gist
    t.index ["continent"], name: "index_neighborhoods_on_continent"
    t.index ["country"], name: "index_neighborhoods_on_country"
    t.index ["geoid"], name: "index_neighborhoods_on_geoid"
    t.index ["geom"], name: "index_neighborhoods_on_geom", using: :gist
    t.index ["slug"], name: "index_neighborhoods_on_slug", unique: true
  end

  create_table "places", force: :cascade do |t|
    t.bigint "neighborhood_id", null: false
    t.string "name"
    t.string "place_type"
    t.decimal "lat", precision: 10, scale: 6
    t.decimal "lon", precision: 10, scale: 6
    t.string "address"
    t.jsonb "tags", default: {}
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "booking_url"
    t.bigint "user_id"
    t.index ["lat", "lon"], name: "index_places_on_lat_and_lon"
    t.index ["neighborhood_id"], name: "index_places_on_neighborhood_id"
    t.index ["place_type"], name: "index_places_on_place_type"
    t.index ["user_id"], name: "index_places_on_user_id"
  end

  create_table "reddit_posts", force: :cascade do |t|
    t.string "post_id"
    t.string "subreddit"
    t.string "title"
    t.text "selftext"
    t.string "url"
    t.datetime "created_utc"
    t.string "context"
    t.string "city"
    t.string "neighborhood"
    t.string "state"
    t.string "country"
    t.float "lat"
    t.float "lon"
    t.float "confidence"
    t.string "risk_level"
    t.float "risk_score"
    t.string "incident_type"
    t.text "summary"
    t.string "status", default: "pending"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["post_id"], name: "index_reddit_posts_on_post_id", unique: true
  end

  create_table "subscriptions", force: :cascade do |t|
    t.string "plan_id"
    t.string "customer_id"
    t.string "subscription_id"
    t.bigint "user_id", null: false
    t.string "status"
    t.string "interval"
    t.datetime "current_period_end"
    t.datetime "current_period_start"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "first_name"
    t.string "last_name"
    t.string "stripe_id"
    t.string "avatar_url"
    t.string "provider"
    t.string "uid"
    t.string "full_name"
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.string "attribution_source"
    t.string "role"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  add_foreign_key "neighborhood_places_stats", "neighborhoods"
  add_foreign_key "places", "neighborhoods"
  add_foreign_key "subscriptions", "users"
end
