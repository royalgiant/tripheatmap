class OfferMessage < ApplicationRecord
  # Associations
  belongs_to :offer
  belongs_to :sender, polymorphic: true

  # Validations
  validates :content, presence: true, length: { minimum: 1, maximum: 2000 }

  # Scopes
  scope :unread, -> { where(read_at: nil) }
  scope :for_user, ->(user) { where(sender: user).or(where.not(sender: user)) }

  # Callbacks
  after_create :send_notification

  # Instance methods
  def mark_read!
    update(read_at: Time.current) if read_at.nil?
  end

  def from_host?
    sender == offer.host_user
  end

  def from_guest?
    sender == offer.guest_user
  end

  private

  def send_notification
    # Send email notification to recipient
    NewMessageMailer.notify(self).deliver_later
  end
end
