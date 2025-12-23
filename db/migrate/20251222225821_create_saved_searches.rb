class CreateSavedSearches < ActiveRecord::Migration[7.1]
  def change
    create_table :saved_searches do |t|
      # User Association
      t.references :user, null: false, foreign_key: true, index: true

      # Core Search Criteria
      t.string :location, null: false # "Toronto", "New York", etc.
      t.integer :max_price_cents, null: false # Store as cents (15000 = $150)
      t.decimal :min_rating, precision: 2, scale: 1 # 4.0, 4.5, 5.0

      # Optional Filters (can be null)
      t.string :price_range # $, $$, $$$, $$$$
      t.string :neighborhood # Single neighborhood slug
      t.jsonb :filters, default: {} # Store complex filters: { neighborhood_slugs: [], etc }

      # Travel Dates (Optional)
      t.date :checkin_date
      t.date :checkout_date

      # Metadata
      t.string :status, default: 'active' # active, paused, expired
      t.boolean :email_verified, default: false
      t.integer :notification_count, default: 0 # Track how many emails sent
      t.datetime :last_notified_at

      # Search Context (for reconstruction)
      t.text :original_url # Store full URL with filters for easy redirect

      t.timestamps
    end

    # Composite index for duplicate detection
    add_index :saved_searches,
              [:user_id, :location, :max_price_cents, :min_rating, :neighborhood],
              name: 'index_saved_searches_on_user_and_criteria'

    # Index for admin querying (for future manual notifications)
    add_index :saved_searches, [:location, :max_price_cents],
              name: 'index_saved_searches_on_location_price'
  end
end
