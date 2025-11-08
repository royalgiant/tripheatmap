class Neighborhood < ApplicationRecord
  has_one :neighborhood_places_stat, dependent: :destroy

  scope :with_geom, -> { where.not(geom: nil) }
end