class RefreshSitemapWorker
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  def perform
    Rails.logger.info "Starting sitemap refresh..."

    # Load rake tasks - this is safe to call multiple times
    Rails.application.load_tasks

    # Run the rake task to refresh sitemap
    Rake::Task["sitemap:refresh"].reenable
    Rake::Task["sitemap:refresh"].invoke

    Rails.logger.info "Sitemap refresh completed successfully"

    # Ping search engines to notify them of the update
    ping_search_engines
  rescue => e
    Rails.logger.error "Sitemap refresh failed: #{e.message}"
    raise e
  end

  private

  def ping_search_engines
    sitemap_url = "https://tripheatmap.com/sitemap.xml"

    # Ping Google
    begin
      Net::HTTP.get(URI("https://www.google.com/ping?sitemap=#{CGI.escape(sitemap_url)}"))
      Rails.logger.info "Pinged Google with sitemap update"
    rescue => e
      Rails.logger.warn "Failed to ping Google: #{e.message}"
    end

    # Ping Bing
    begin
      Net::HTTP.get(URI("https://www.bing.com/ping?sitemap=#{CGI.escape(sitemap_url)}"))
      Rails.logger.info "Pinged Bing with sitemap update"
    rescue => e
      Rails.logger.warn "Failed to ping Bing: #{e.message}"
    end
  end
end
