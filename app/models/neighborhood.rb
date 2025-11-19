class Neighborhood < ApplicationRecord
  has_one :neighborhood_places_stat, dependent: :destroy
  has_many :places, dependent: :destroy

  validates :name, :city, :state, presence: true

  # Normalize city names to lowercase before validation
  before_validation :normalize_city_name
  before_validation :generate_slug, if: :slug_should_be_generated?

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
end