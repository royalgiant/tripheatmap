class Place < ApplicationRecord
  belongs_to :neighborhood
  belongs_to :user, optional: true

  validates :name, presence: true
  validates :place_type, presence: true
  validates :lat, :lon, presence: true

  before_save :generate_slug, if: :should_generate_slug?

  PLACE_TYPES = %w[
    restaurant cafe bar hotel hostel airbnb vrbo
    attraction museum monument viewpoint airport university beach
    convention_center theme_park zoo park
  ].freeze

  scope :restaurants, -> { where(place_type: 'restaurant') }
  scope :cafes, -> { where(place_type: 'cafe') }
  scope :bars, -> { where(place_type: 'bar') }
  scope :hotels, -> { where(place_type: 'hotel') }
  scope :hostels, -> { where(place_type: 'hostel') }
  scope :accommodations, -> { where(place_type: ['hotel', 'hostel']) }
  scope :airbnbs, -> { where(place_type: 'airbnb') }
  scope :vrbos, -> { where(place_type: 'vrbo') }
  scope :rentals, -> { where(place_type: ['airbnb', 'vrbo']) }
  scope :landmarks, -> { where(place_type: ['attraction', 'museum', 'monument', 'viewpoint', 'airport', 'university', 'beach', 'convention_center', 'theme_park', 'zoo', 'park']) }
  scope :by_type, ->(type) { where(place_type: type) }
  scope :with_ratings, -> { where.not(rating: nil) }
  scope :highly_rated, -> { where('rating >= ?', 4.0) }

  def wikimedia_image?
    tags&.dig('wikimedia_commons').present?
  end

  def wikimedia_image_url(width: 200)
    filename = tags&.dig('wikimedia_commons')
    return nil unless filename.present?
    filename = filename.sub(/^File:/, '').gsub(' ', '_')
    encoded_filename = ERB::Util.url_encode(filename)
    "https://commons.wikimedia.org/wiki/Special:Redirect/file/#{encoded_filename}?width=#{width}"
  end

  private

  def should_generate_slug?
    slug.blank? || name_changed?
  end

  def generate_slug
    base_slug = name.to_s.parameterize
    return if base_slug.blank?

    city_part = neighborhood&.city&.parameterize || 'unknown'
    neighborhood_part = neighborhood&.name&.parameterize&.first(20) || 'unknown'

    unique_slug = "#{base_slug}-#{city_part}-#{neighborhood_part}"

    counter = 1
    final_slug = unique_slug
    while Place.where(slug: final_slug).where.not(id: id).exists?
      final_slug = "#{unique_slug}-#{counter}"
      counter += 1
    end

    self.slug = final_slug
  end
end
