class OfferCleanupJob < ApplicationJob
  queue_as :default

  def perform
    # This job runs weekly (Sundays at 2 AM)
    # Deletes expired/declined offers older than 90 days
    # Keeps accepted offers forever for records

    deleted_count = Offer
      .where(status: ['expired', 'declined'])
      .where('updated_at < ?', 90.days.ago)
      .delete_all

    Rails.logger.info "[OfferCleanup] Deleted #{deleted_count} old offers"
  end
end
