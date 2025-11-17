class Place < ApplicationRecord
  belongs_to :neighborhood
  belongs_to :user, optional: true

  validates :name, presence: true
  validates :place_type, presence: true
  validates :lat, :lon, presence: true

  PLACE_TYPES = %w[restaurant cafe bar airbnb vrbo].freeze

  scope :restaurants, -> { where(place_type: 'restaurant') }
  scope :cafes, -> { where(place_type: 'cafe') }
  scope :bars, -> { where(place_type: 'bar') }
  scope :airbnbs, -> { where(place_type: 'airbnb') }
  scope :vrbos, -> { where(place_type: 'vrbo') }
  scope :rentals, -> { where(place_type: ['airbnb', 'vrbo']) }
  scope :by_type, ->(type) { where(place_type: type) }
end
