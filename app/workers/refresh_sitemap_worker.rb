class RefreshSitemapWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  def perform
    Rails.logger.info "Starting sitemap refresh..."

    # Run the rake task to refresh sitemap
    system("bundle exec rake sitemap:refresh")

    Rails.logger.info "Sitemap refresh completed successfully"
  rescue => e
    Rails.logger.error "Sitemap refresh failed: #{e.message}"
    raise e
  end
end
