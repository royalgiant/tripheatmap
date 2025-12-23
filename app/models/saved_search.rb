class SavedSearch < ApplicationRecord
  belongs_to :user

  validates :location, :max_price_cents, presence: true
  validates :max_price_cents, numericality: { greater_than: 0 }
  validates :min_rating, inclusion: { in: [3.0, 3.5, 4.0, 4.5, 5.0] }, allow_nil: true
  validates :status, inclusion: { in: %w[active paused expired] }

  scope :active, -> { where(status: 'active') }
  scope :for_location, ->(location) { where(location: location) }
  scope :under_price, ->(price_cents) { where('max_price_cents <= ?', price_cents) }

  # Prevent exact duplicates for same user
  validates :location, uniqueness: {
    scope: [:user_id, :max_price_cents, :min_rating, :neighborhood],
    message: "search already exists with these exact filters"
  }

  # Convert max_price from dollars to cents
  def max_price
    max_price_cents / 100.0 if max_price_cents
  end

  def max_price=(dollars)
    self.max_price_cents = (dollars.to_f * 100).to_i
  end

  # Reconstruct URL from stored filters or use original_url
  def to_filter_url
    original_url || build_url_from_filters
  end

  # Human-readable filter summary
  def filter_summary
    parts = []
    parts << "Max $#{max_price.to_i}" if max_price_cents
    parts << "#{min_rating}+ stars" if min_rating
    parts << price_range if price_range.present?
    parts << neighborhood if neighborhood.present?
    parts.join(', ')
  end

  # Human-readable date range
  def date_range
    if checkin_date && checkout_date
      "#{checkin_date.strftime('%b %d')} - #{checkout_date.strftime('%b %d, %Y')}"
    else
      "Flexible"
    end
  end

  private

  def build_url_from_filters
    # This would reconstruct the URL based on stored filters
    # For now, we'll rely on original_url being set
    nil
  end
end
