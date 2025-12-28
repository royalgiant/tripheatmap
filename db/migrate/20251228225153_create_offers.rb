class CreateOffers < ActiveRecord::Migration[7.1]
  def change
    create_table :offers do |t|
      t.references :place, null: false, foreign_key: true
      t.references :saved_search, null: false, foreign_key: true
      t.integer :offered_price_cents, null: false
      t.string :discount_type
      t.decimal :discount_value, precision: 10, scale: 2
      t.jsonb :perks, default: [], null: false
      t.text :personal_message
      t.datetime :expires_at, null: false
      t.string :status, default: 'sent', null: false
      t.datetime :viewed_at
      t.datetime :accepted_at

      t.timestamps
    end

    # Unique constraint: one offer per place per saved_search
    add_index :offers, [:place_id, :saved_search_id], unique: true

    # Query optimization indexes
    add_index :offers, :status
    add_index :offers, :expires_at
    add_index :offers, [:saved_search_id, :status]
  end
end
