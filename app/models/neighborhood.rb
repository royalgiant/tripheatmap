class Neighborhood < ApplicationRecord
  has_one :neighborhood_places_stat, dependent: :destroy
  has_many :places, dependent: :destroy

  validates :name, :city, :state, presence: true

  geocoded_by :latitude => :latitude, :longitude => :longitude

  before_validation :normalize_city_name
  before_validation :generate_slug, if: :slug_should_be_generated?
  before_save :calculate_area_sq_km, if: :should_calculate_area?
  before_save :calculate_centroid, if: :should_calculate_centroid?
  before_save :update_lat_lon_from_centroid, if: :should_update_lat_lon?

  scope :with_geom, -> { where.not(geom: nil) }

  # Case-insensitive city lookup
  scope :for_city, ->(city_name) { where(city: city_name.to_s.downcase) if city_name.present? }

  def to_param
    slug
  end

  private

  def normalize_city_name
    self.city = city.to_s.downcase if city.present?
  end

  def slug_should_be_generated?
    slug.blank? || name_changed? || city_changed? || state_changed?
  end

  def generate_slug
    # parameterize handles:
    # - "Los Angeles" -> "los-angeles"
    # - "St. Louis" -> "st-louis"
    # - "Washington, D.C." -> "washington-dc"
    # - Accents: "Montréal" -> "montreal"
    # - Special chars removed
    base_slug = [name, city, state].compact.join('-').parameterize

    # Ensure uniqueness
    slug_candidate = base_slug
    counter = 1
    while Neighborhood.where(slug: slug_candidate).where.not(id: id).exists?
      slug_candidate = "#{base_slug}-#{counter}"
      counter += 1
    end

    self.slug = slug_candidate
  end

  def should_calculate_area?
    geom.present? && (geom_changed? || area_sq_km.blank?)
  end

  def calculate_area_sq_km
    result = self.class.connection.select_value(
      "SELECT ST_Area(ST_GeomFromText('#{geom.as_text}', 4326)::geography) / 1000000.0"
    )
    self.area_sq_km = result.to_f if result
  end

  def should_calculate_centroid?
    geom.present? && (geom_changed? || centroid.blank?)
  end

  def calculate_centroid
    result = self.class.connection.select_value(
      "SELECT ST_Centroid(ST_GeomFromText('#{geom.as_text}', 4326)::geography)"
    )
    self.centroid = result if result
  end

  def should_update_lat_lon?
    centroid.present? && (centroid_changed? || latitude.blank? || longitude.blank?)
  end

  def update_lat_lon_from_centroid
    self.latitude = centroid.latitude
    self.longitude = centroid.longitude
  end
end