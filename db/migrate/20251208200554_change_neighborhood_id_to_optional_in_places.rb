class ChangeNeighborhoodIdToOptionalInPlaces < ActiveRecord::Migration[7.1]
  def change
    change_column_null :places, :neighborhood_id, true
  end
end
