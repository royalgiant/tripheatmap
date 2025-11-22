# Sidekiq worker for fetching and caching Wikipedia images for neighborhoods
# Runs periodically to warm the cache for where-to-stay pages
#
# Usage:
#   FetchWikipediaImagesJob.perform_async
#
class FetchWikipediaImagesJob
  include Sidekiq::Worker

  sidekiq_options queue: :default, retry: 3

  def perform
    Rails.logger.info "FetchWikipediaImagesJob started"

    # Find neighborhoods that need Wikipedia images fetched/refreshed
    # Either they have no image, or the image was checked more than 30 days ago
    neighborhoods = Neighborhood
      .where("wikipedia_image_checked_at IS NULL OR wikipedia_image_checked_at < ?", 30.days.ago)
      .limit(100) # Process 100 at a time to avoid overwhelming Wikipedia API

    success_count = 0
    failed_count = 0

    neighborhoods.each do |neighborhood|
      begin
        city_name = neighborhood.city
        wiki_image = fetch_wikipedia_image(neighborhood.name, city_name)

        if wiki_image.present?
          neighborhood.update_columns(
            wikipedia_image_url: wiki_image,
            wikipedia_image_checked_at: Time.current
          )
          success_count += 1
        else
          # Mark as checked even if no image found to avoid repeated API calls
          neighborhood.update_columns(
            wikipedia_image_url: nil,
            wikipedia_image_checked_at: Time.current
          )
        end

        # Rate limiting: sleep briefly between API calls
        sleep(0.5)
      rescue => e
        Rails.logger.error "Failed to fetch Wikipedia image for #{neighborhood.name}: #{e.message}"
        failed_count += 1
      end
    end

    Rails.logger.info "FetchWikipediaImagesJob completed: #{success_count} succeeded, #{failed_count} failed"
    { success: success_count, failed: failed_count }
  end

  private

  def fetch_wikipedia_image(neighborhood_name, city_name)
    search_terms = [
      "#{neighborhood_name}, #{city_name}",
      neighborhood_name
    ]

    search_terms.each do |term|
      image_url = wikipedia_page_image(term)
      return image_url if image_url.present?
    end

    nil
  rescue => e
    Rails.logger.error "Wikipedia image fetch failed: #{e.message}"
    nil
  end

  def wikipedia_page_image(title)
    url = "https://en.wikipedia.org/w/api.php"
    params = {
      action: 'query',
      titles: title,
      prop: 'pageimages',
      format: 'json',
      pithumbsize: 600
    }

    response = Faraday.get(url, params)
    return nil unless response.success?

    data = JSON.parse(response.body)
    pages = data.dig('query', 'pages')
    return nil unless pages

    page = pages.values.first
    page&.dig('thumbnail', 'source')
  rescue => e
    Rails.logger.error "Wikipedia API error for '#{title}': #{e.message}"
    nil
  end
end
