class Favorite < ApplicationRecord
  belongs_to :user
  belongs_to :place

  validates :user_id, uniqueness: { scope: :place_id, message: "has already favorited this place" }
end
