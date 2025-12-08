class AddLocationDataToPlaces < ActiveRecord::Migration[7.1]
  def up
    add_column :places, :city, :string
    add_column :places, :state, :string
    add_column :places, :country, :string
    add_column :places, :continent, :string

    # Add indexes for common queries
    add_index :places, :city
    add_index :places, [:city, :place_type]
    add_index :places, [:country, :continent]

    # Note: Backfilling 600k places will be done in batches via a rake task
    # to avoid long-running migration during deployment
    # Run: rake places:backfill_location_data after deployment
  end

  def down
    remove_index :places, :city
    remove_index :places, [:city, :place_type]
    remove_index :places, [:country, :continent]

    remove_column :places, :city
    remove_column :places, :state
    remove_column :places, :country
    remove_column :places, :continent
  end
end
