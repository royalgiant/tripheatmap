class AddUniquenessConstraintToOffers < ActiveRecord::Migration[7.1]
  def change
    add_index :offers, [:place_id, :saved_search_id], unique: true, name: 'index_offers_on_place_and_saved_search'
  end
end
