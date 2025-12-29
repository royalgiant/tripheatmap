class OfferMessage < ApplicationRecord
  # Associations
  belongs_to :offer
  belongs_to :sender, polymorphic: true

  # Validations
  validates :content, presence: true, length: { minimum: 1, maximum: 2000 }

  # Scopes
  scope :unread, -> { where(read_at: nil) }
  scope :for_user, ->(user) {
    joins(offer: [:place, :saved_search])
      .where(places: { user_id: user.id })
      .or(joins(offer: [:place, :saved_search]).where(saved_searches: { user_id: user.id }))
  }

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
    recipient = from_host? ? offer.guest_user : offer.host_user
    preference = recipient.email_preference
    return unless preference&.receive_any_emails
    return unless preference&.receive_message_emails

    NewMessageMailer.notify(self).deliver_later
  end
end
