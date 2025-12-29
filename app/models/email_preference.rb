class EmailPreference < ApplicationRecord
  belongs_to :user

  # Enum for email frequency preferences
  # never: 0, daily_digest: 1, weekly_digest: 2
  enum new_lead_email_frequency: {
    never: 0,
    daily_digest: 1,
    weekly_digest: 2
  }, _prefix: :new_lead

  enum new_offer_email_frequency: {
    never: 0,
    daily_digest: 1,
    weekly_digest: 2
  }, _prefix: :new_offer

  validates :user, presence: true, uniqueness: true
end
