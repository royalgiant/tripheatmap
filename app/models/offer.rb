class Offer < ApplicationRecord
  # Associations
  belongs_to :place
  belongs_to :saved_search
  has_many :messages, class_name: 'OfferMessage', dependent: :destroy

  # Delegations
  delegate :user, to: :place, prefix: :host, allow_nil: true
  delegate :user, to: :saved_search, prefix: :guest

  # Enums
  enum discount_type: {
    percentage: 'percentage',
    fixed_amount: 'fixed_amount'
  }, _prefix: true

  enum status: {
    sent: 'sent',
    viewed: 'viewed',
    accepted: 'accepted',
    declined: 'declined',
    expired: 'expired'
  }, _prefix: true

  # Validations
  validates :offered_price_cents, presence: true, numericality: { greater_than: 0 }
  validates :expires_at, presence: true
  validates :status, presence: true, inclusion: { in: statuses.keys }
  validates :personal_message, length: { maximum: 500 }, allow_blank: true
  validates :saved_search_id, uniqueness: { scope: :place_id, message: "already has an offer from this property" }
  validate :price_within_budget
  validate :expiration_in_future, on: :create

  # Scopes
  scope :active, -> { where(status: ['sent', 'viewed']) }
  scope :expiring_soon, -> { where('expires_at BETWEEN ? AND ?', Time.current, 24.hours.from_now) }
  scope :for_guest, ->(user) { joins(:saved_search).where(saved_searches: { user_id: user.id }) }
  scope :for_host, ->(user) { joins(:place).where(places: { user_id: user.id }) }

  # Callbacks
  after_update :mark_as_viewed, if: :viewed_at_changed?

  # Instance methods
  def discount_description
    return "No discount" if discount_value.blank?

    case discount_type
    when 'percentage'
      "#{discount_value.to_i}% off"
    when 'fixed_amount'
      "$#{discount_value.to_i} off"
    else
      "Special offer"
    end
  end

  def time_remaining
    return "Expired" if expired? || expires_at < Time.current

    distance = expires_at - Time.current
    if distance < 1.hour
      "#{(distance / 60).to_i} minutes"
    elsif distance < 24.hours
      "#{(distance / 3600).to_i} hours"
    else
      "#{(distance / 86400).to_i} days"
    end
  end

  def perks_list
    return "None" if perks.blank? || perks.empty?
    perks.join(", ")
  end

  def mark_viewed!
    update(viewed_at: Time.current, status: 'viewed') if viewed_at.nil?
  end

  def expired?
    status == 'expired'
  end

  private

  def price_within_budget
    return unless saved_search && offered_price_cents

    if offered_price_cents > saved_search.max_price_cents
      errors.add(:offered_price_cents, "must be within guest's budget ($#{saved_search.max_price_cents / 100})")
    end
  end

  def expiration_in_future
    return unless expires_at

    if expires_at <= Time.current
      errors.add(:expires_at, "must be in the future")
    end
  end

  def mark_as_viewed
    update_column(:status, 'viewed') if status == 'sent' && viewed_at.present?
  end
end
