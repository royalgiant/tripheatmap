class Neighborhood < ApplicationRecord
  has_one :neighborhood_places_stat, dependent: :destroy
  has_many :places, dependent: :destroy

  # Normalize city names to lowercase before validation
  before_validation :normalize_city_name

  scope :with_geom, -> { where.not(geom: nil) }

  # Case-insensitive city lookup
  scope :for_city, ->(city_name) { where(city: city_name.to_s.downcase) if city_name.present? }

  private

  def normalize_city_name
    self.city = city.to_s.downcase if city.present?
  end
end