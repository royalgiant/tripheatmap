class AddAirbnbVrboMetadataToPlaces < ActiveRecord::Migration[7.1]
  def change
    add_column :places, :airbnb_vrbo_metadata, :jsonb
  end
end
