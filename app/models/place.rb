class Place < ApplicationRecord
  belongs_to :neighborhood

  validates :name, presence: true
  validates :place_type, presence: true
  validates :lat, :lon, presence: true

  PLACE_TYPES = %w[restaurant cafe bar].freeze

  scope :restaurants, -> { where(place_type: 'restaurant') }
  scope :cafes, -> { where(place_type: 'cafe') }
  scope :bars, -> { where(place_type: 'bar') }
  scope :by_type, ->(type) { where(place_type: type) }
end
