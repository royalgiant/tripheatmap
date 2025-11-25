class Place < ApplicationRecord
  belongs_to :neighborhood
  belongs_to :user, optional: true

  validates :name, presence: true
  validates :place_type, presence: true
  validates :lat, :lon, presence: true

  PLACE_TYPES = %w[restaurant cafe bar hotel hostel airbnb vrbo].freeze

  scope :restaurants, -> { where(place_type: 'restaurant') }
  scope :cafes, -> { where(place_type: 'cafe') }
  scope :bars, -> { where(place_type: 'bar') }
  scope :hotels, -> { where(place_type: 'hotel') }
  scope :hostels, -> { where(place_type: 'hostel') }
  scope :accommodations, -> { where(place_type: ['hotel', 'hostel']) }
  scope :airbnbs, -> { where(place_type: 'airbnb') }
  scope :vrbos, -> { where(place_type: 'vrbo') }
  scope :rentals, -> { where(place_type: ['airbnb', 'vrbo']) }
  scope :by_type, ->(type) { where(place_type: type) }
  scope :with_ratings, -> { where.not(rating: nil) }
  scope :highly_rated, -> { where('rating >= ?', 4.0) }
end
