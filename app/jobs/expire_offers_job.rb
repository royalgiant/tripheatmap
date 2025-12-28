class ExpireOffersJob < ApplicationJob
  queue_as :default

  def perform
    # This job runs hourly
    # Marks offers past their expiration date as expired

    expired_count = Offer
      .where(status: ['sent', 'viewed'])
      .where('expires_at < ?', Time.current)
      .update_all(status: 'expired')

    Rails.logger.info "[ExpireOffers] Marked #{expired_count} offers as expired"
  end
end
