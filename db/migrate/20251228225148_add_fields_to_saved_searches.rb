class AddFieldsToSavedSearches < ActiveRecord::Migration[7.1]
  def change
    add_column :saved_searches, :number_of_guests, :integer

    # Status column already exists, just add index if not present
    add_index :saved_searches, :status unless index_exists?(:saved_searches, :status)
  end
end
