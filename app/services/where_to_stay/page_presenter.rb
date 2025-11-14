module WhereToStay
  class PagePresenter
    PLACE_TYPE_PRIORITY = {
      "restaurant" => 0,
      "bar" => 1,
      "cafe" => 2
    }.freeze

    attr_reader :city_name, :state, :neighborhood_cards, :city_intro, :total_neighborhoods

    def initialize(city_slug:, city_config:, url_slug:)
      @city_slug = city_slug
      @url_slug = url_slug
      @city_config = city_config.with_indifferent_access
      @city_name = @city_config[:name] || city_slug.titleize
      @state = @city_config[:state]
      @neighborhood_cards = []
      @faq_items = []
      @city_intro = ""
      @total_neighborhoods = 0

      build_page_data
    end

    def available?
      neighborhood_cards.any?
    end

    def hero_heading
      "Where to Stay in #{@city_name}, #{@state} – 2025 Ranking of the Best Neighborhoods (Data-Driven)"
    end

    def hero_summary
      return "" unless available?

      "We analyzed #{@total_neighborhoods} neighborhoods in #{@city_name}, using TripHeatmap vibrancy, restaurant/bar/café density per km², and real venue data to surface the best places to visit or stay."
    end

    def quick_summary
      neighborhood_cards.first(3).map do |card|
        "#{card[:name]} · #{format_score(card[:vibrancy_score])}"
      end
    end

    def map_url
      "/maps/places/#{@url_slug}"
    end

    def faq_items
      @faq_items
    end

    def neighborhood_count
      @total_neighborhoods
    end

    private

    def build_page_data
      neighborhoods = fetch_neighborhoods
      return if neighborhoods.empty?

      metrics = build_metrics_without_places(neighborhoods)
      return if metrics.empty?

      @total_neighborhoods = metrics.size
      thresholds = build_thresholds(metrics)
      tag_assigner = TagAssigner.new(thresholds)
      top_metrics = metrics.first(30)
      top_neighborhood_ids = top_metrics.map { |m| m[:neighborhood].id }
      @places_by_neighborhood = places_for(top_neighborhood_ids)

      @neighborhood_cards = build_cards(top_metrics, tag_assigner)
      @city_intro = build_city_intro
      @faq_items = build_faq_items(metrics)
    end

    def fetch_neighborhoods
      Neighborhood
        .for_city(@city_slug)
        .with_geom
        .includes(:neighborhood_places_stat)
        .select("neighborhoods.*, ST_Area(neighborhoods.geom::geography) / 1000000.0 AS area_sq_km")
        .order(Arel.sql("neighborhood_places_stats.vibrancy_index DESC NULLS LAST"))
    end

    def build_metrics_without_places(neighborhoods)
      return [] if neighborhoods.empty?

      neighborhoods.filter_map do |neighborhood|
        next if neighborhood.name.to_s.match?(/\bTract\b/i)

        stats = neighborhood.neighborhood_places_stat
        next unless stats&.vibrancy_index

        # Read pre-calculated densities from database
        densities = {
          restaurants: stats.restaurants_vibrancy.to_f,
          cafes: stats.cafes_vibrancy.to_f,
          bars: stats.bars_vibrancy.to_f
        }

        counts = {
          restaurants: stats.restaurant_count.to_i,
          cafes: stats.cafe_count.to_i,
          bars: stats.bar_count.to_i
        }

        {
          neighborhood: neighborhood,
          stats: stats,
          counts: counts,
          densities: densities,
          vibrancy: stats.vibrancy_index.to_f,
          area_sq_km: neighborhood.read_attribute(:area_sq_km).to_f,
          total_amenities: stats.total_amenities.to_i.nonzero? || counts.values.sum
        }
      end.sort_by { |metric| [-metric[:vibrancy], metric[:neighborhood].name] }
    end

    def build_thresholds(metrics)
      density_samples = {
        restaurants: metrics.map { |metric| metric[:densities][:restaurants] },
        cafes: metrics.map { |metric| metric[:densities][:cafes] },
        bars: metrics.map { |metric| metric[:densities][:bars] }
      }

      {
        vibrancy: percentile(metrics.map { |metric| metric[:vibrancy] }, 0.75),
        restaurants: percentile(density_samples[:restaurants], 0.8),
        cafes: percentile(density_samples[:cafes], 0.75),
        bars: percentile(density_samples[:bars], 0.75)
      }
    end

    def build_cards(metrics, tag_assigner)
      metrics.map.with_index(1) do |metric, rank|
        neighborhood = metric[:neighborhood]
        densities = metric[:densities]
        stats = metric[:counts]

        {
          rank: rank,
          neighborhood_id: neighborhood.id,
          name: neighborhood.name,
          vibrancy_score: metric[:vibrancy]&.round(1),
          tags: tag_assigner.tags_for(vibrancy: metric[:vibrancy], densities: densities),
          densities: format_densities(densities),
          amenities: stats,
          area_sq_km: metric[:area_sq_km],
          map_image_url: map_image_url_for(neighborhood),
          highlights: build_highlights(neighborhood.id),
          neighborhood_path: Rails.application.routes.url_helpers.neighborhood_path(neighborhood),
          description: build_description(neighborhood.name, metric)
        }
      end
    end

    def build_city_intro
      return "" unless available?
      top = neighborhood_cards.first

      "#{top[:name]} currently leads #{@city_name}'s #{@total_neighborhoods}-neighborhood ranking with a #{format_score(top[:vibrancy_score])} vibrancy score and #{top[:amenities][:restaurants]} restaurants, #{top[:amenities][:cafes]} cafés, and #{top[:amenities][:bars]} bars. Use the live heatmap to compare every district before you pick a place to stay."
    end

    def build_faq_items(metrics)
      return [] unless available?

      most_food = metrics.max_by { |metric| metric[:densities][:restaurants] }
      most_nightlife = metrics.max_by { |metric| metric[:densities][:bars] }
      most_remote = metrics.max_by { |metric| metric[:densities][:cafes] }

      items = [
        {
          question: "Where do first-time visitors usually stay in #{@city_name}?",
          answer: "Start with #{neighborhood_cards.first[:name]} – it tops our #{@total_neighborhoods}-area leaderboard with a #{format_score(neighborhood_cards.first[:vibrancy_score])} vibrancy index and immediate access to #{neighborhood_cards.first[:amenities][:restaurants]} restaurants plus #{neighborhood_cards.first[:amenities][:bars]} bars."
        },
        {
          question: "Which neighborhood is best for food lovers?",
          answer: answer_for_highlight(most_food, :restaurants)
        },
        {
          question: "Where should I stay for nightlife in #{@city_name}?",
          answer: answer_for_highlight(most_nightlife, :bars)
        },
        {
          question: "Is there a good base for remote workers?",
          answer: answer_for_highlight(most_remote, :cafes)
        }
      ]

      items.select { |item| item[:answer].present? }
    end

    def answer_for_highlight(metric, key)
      return nil unless metric

      neighborhood = metric[:neighborhood]
      counts = metric[:counts]

      case key
      when :restaurants
        "#{neighborhood.name} has #{counts[:restaurants]} restaurants along with #{metric[:total_amenities]} total venues, so you can walk to dozens of spots within walking distance of each other."
      when :bars
        "#{neighborhood.name} edges out the rest of the city for nightlife, with #{counts[:bars]} bars and a #{format_score(metric[:vibrancy])} vibrancy score that holds up into the late hours."
      when :cafes
        "#{neighborhood.name} has #{counts[:cafes]} cafés plus #{counts[:restaurants]} restaurants, so it's easy to plug in and work between adventures."
      else
        nil
      end
    end

    def format_densities(densities)
      {
        restaurants_per_sq_km: format_density_value(densities[:restaurants]),
        cafes_per_sq_km: format_density_value(densities[:cafes]),
        bars_per_sq_km: format_density_value(densities[:bars])
      }
    end

    def format_density_value(value)
      value && value.positive? ? format("%.1f", value) : "0.0"
    end

    def build_description(name, metric)
      restaurants = metric[:counts][:restaurants]
      bars = metric[:counts][:bars]
      cafes = metric[:counts][:cafes]
      dens = metric[:densities][:restaurants]

      "#{name} mixes #{restaurants} restaurants, #{cafes} cafés, and #{bars} bars packed into #{metric[:area_sq_km].round(2)} km², making it a reliable base for visitors chasing real energy."
    end

    def map_image_url_for(neighborhood)
      if neighborhood.wikipedia_image_url.present? &&
         neighborhood.wikipedia_image_checked_at.present? &&
         neighborhood.wikipedia_image_checked_at > 30.days.ago
        return neighborhood.wikipedia_image_url
      end

      wiki_image = fetch_and_cache_wikipedia_image(neighborhood)
      return wiki_image if wiki_image.present?

      token = Rails.application.credentials.dig(Rails.env.to_sym, :mapbox, :public_key)
      return nil if token.blank? || neighborhood.centroid.blank?

      lon = neighborhood.centroid.longitude
      lat = neighborhood.centroid.latitude
      "https://api.mapbox.com/styles/v1/mapbox/streets-v11/static/#{lon},#{lat},13,0/600x360?attribution=false&logo=false&access_token=#{token}"
    end

    def fetch_and_cache_wikipedia_image(neighborhood)
      if neighborhood.wikipedia_image_url.present?
        if image_url_valid?(neighborhood.wikipedia_image_url)
          neighborhood.update_columns(wikipedia_image_checked_at: Time.current)
          return neighborhood.wikipedia_image_url
        else
          Rails.logger.info "Wikipedia image broken for #{neighborhood.name}, refetching..."
        end
      end

      wiki_image = fetch_wikipedia_image(neighborhood.name, @city_name)

      if wiki_image.present?
        # Cache the URL and timestamp
        neighborhood.update_columns(
          wikipedia_image_url: wiki_image,
          wikipedia_image_checked_at: Time.current
        )
      else
        # No Wikipedia image found, mark as checked to avoid repeated API calls
        neighborhood.update_columns(
          wikipedia_image_url: nil,
          wikipedia_image_checked_at: Time.current
        )
      end

      wiki_image
    rescue => e
      Rails.logger.error "Failed to fetch/cache Wikipedia image: #{e.message}"
      nil
    end

    def image_url_valid?(url)
      response = Faraday.head(url) do |req|
        req.options.timeout = 3 # Quick HEAD request to check if image URL still works
      end
      response.success?
    rescue Faraday::TimeoutError, Faraday::ConnectionFailed => e
      Rails.logger.warn "Image validation failed for #{url}: #{e.message}"
      false
    rescue => e
      Rails.logger.warn "Unexpected error validating image #{url}: #{e.message}"
      false
    end

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

    def build_highlights(neighborhood_id)
      places = @places_by_neighborhood[neighborhood_id] || []
      places
        .sort_by { |place| [PLACE_TYPE_PRIORITY.fetch(place.place_type, 99), place.name.to_s.downcase] }
        .first(3)
        .map do |place|
          {
            name: place.name,
            type: place.place_type,
            address: place.address
          }
        end
    end

    def places_for(neighborhood_ids)
      return {} if neighborhood_ids.empty?

      # Use window function to get only top 3 places per neighborhood
      # This is much faster than loading all places
      sql = <<~SQL
        SELECT id, name, place_type, neighborhood_id, address
        FROM (
          SELECT
            id,
            name,
            place_type,
            neighborhood_id,
            address,
            ROW_NUMBER() OVER (
              PARTITION BY neighborhood_id
              ORDER BY
                CASE place_type
                  WHEN 'restaurant' THEN 0
                  WHEN 'bar' THEN 1
                  WHEN 'cafe' THEN 2
                  ELSE 99
                END,
                LOWER(name)
            ) as rn
          FROM places
          WHERE neighborhood_id IN (#{neighborhood_ids.join(',')})
            AND place_type IN ('restaurant', 'bar', 'cafe')
        ) ranked
        WHERE rn <= 3
      SQL

      Place.find_by_sql(sql).group_by(&:neighborhood_id)
    end

    def percentile(values, percentile_rank)
      sorted = values.compact.sort
      return nil if sorted.empty?
      index = (percentile_rank * (sorted.length - 1)).round
      sorted[index]
    end

    def format_score(score)
      score ? format("%.1f / 10", score) : "N/A"
    end
  end
end
