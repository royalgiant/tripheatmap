class RefreshSitemapWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  def perform
    Rails.logger.info "Starting sitemap refresh..."

    # Load rake tasks if not already loaded
    Rails.application.load_tasks unless defined?(Rake::Task)

    # Run the rake task to refresh sitemap
    Rake::Task["sitemap:refresh"].reenable
    Rake::Task["sitemap:refresh"].invoke

    Rails.logger.info "Sitemap refresh completed successfully"
  rescue => e
    Rails.logger.error "Sitemap refresh failed: #{e.message}"
    raise e
  end
end
