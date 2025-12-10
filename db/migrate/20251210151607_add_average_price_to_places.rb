class AddAveragePriceToPlaces < ActiveRecord::Migration[7.1]
  def change
    add_column :places, :average_price, :decimal, precision: 10, scale: 2, comment: "Average nightly price in USD (AI-generated estimate)"
  end
end
