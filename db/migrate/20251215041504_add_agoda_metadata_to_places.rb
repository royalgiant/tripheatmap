class AddAgodaMetadataToPlaces < ActiveRecord::Migration[7.1]
  def change
    add_column :places, :agoda_metadata, :jsonb
  end
end
