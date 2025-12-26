class RentalMetadataFetcher
  require 'nokogiri'
  require 'faraday'
  require 'json'

  def initialize(url)
    @url = url
  end

  def call
    return {} if @url.blank?

    begin
      html = fetch_html
      return {} if html.blank?
      
      doc = Nokogiri::HTML(html)
      
      # Try to extract from structured JSON-LD first (preferred for Airbnb/VRBO)
      metadata = extract_from_json_ld(doc)
      
      # If structured data is missing or incomplete, fall back to meta tags/scraping
      if metadata.values.all?(&:blank?)
        metadata = parse_metadata_fallback(doc)
      else
        # Merge fallback for any missing keys (e.g. if JSON-LD has title but no amenities)
        fallback = parse_metadata_fallback(doc)
        metadata = fallback.merge(metadata.compact)
      end

      normalize_metadata(metadata)
    rescue StandardError => e
      Rails.logger.error("RentalMetadataFetcher Error for URL #{@url}: #{e.message}")
      {}
    end
  end

  private

  def normalize_metadata(metadata)
    normalized = {}

    # String fields - strip whitespace
    normalized[:title] = metadata[:title]&.strip&.presence
    normalized[:description] = metadata[:description]&.strip&.presence

    # Image fields - separate main image from gallery
    normalized[:main_image] = metadata[:main_image]&.strip&.presence
    normalized[:images] = Array.wrap(metadata[:images]).compact.presence

    # Array fields - ensure array and remove nils
    normalized[:amenities] = Array.wrap(metadata[:amenities]).compact.presence

    # Numeric fields - ensure proper type
    normalized[:rating] = metadata[:rating]&.to_f&.presence
    normalized[:review_count] = metadata[:review_count]&.to_i&.presence

    # Property details - ensure integers
    normalized[:guests] = metadata[:guests]&.to_i&.presence
    normalized[:bedrooms] = metadata[:bedrooms]&.to_i&.presence
    normalized[:beds] = metadata[:beds]&.to_i&.presence
    normalized[:baths] = metadata[:baths]&.to_f&.presence

    # Host info - strings
    normalized[:host_image_url] = metadata[:host_image_url]&.strip&.presence
    normalized[:is_superhost] = metadata[:is_superhost] if metadata.key?(:is_superhost)

    # Remove nil/empty values
    normalized.compact
  end

  def fetch_html
    url_to_fetch = @url
    limit = 3

    while limit > 0
      response = Faraday.get(url_to_fetch) do |req|
        req.headers['User-Agent'] = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
      end

      if response.status == 301 || response.status == 302
        url_to_fetch = response.headers['Location']
        limit -= 1
      elsif response.success?
        return response.body
      elsif response.status == 429
        Rails.logger.warn("RentalMetadataFetcher: Bot detection encountered (429) for #{@url}")
        return nil
      else
        Rails.logger.error("RentalMetadataFetcher failed with status #{response.status} for #{@url}")
        return nil
      end
    end
    nil
  end

  def extract_from_json_ld(doc)
    metadata = {}

    doc.css('script[type="application/ld+json"]').each do |script|
      begin
        json = JSON.parse(script.text)
        # Airbnb/VRBO often use 'VacationRental', 'Accommodation', 'Product', or 'Hotel'
        types = Array.wrap(json['@type'])

        if (types & ['VacationRental', 'Apartment', 'Hotel', 'Accommodation', 'Product']).any?
          metadata[:title] = json['name']&.to_s&.strip
          metadata[:description] = json['description']&.to_s&.strip

          # Normalize images - first is main_image, rest are gallery
          all_images = Array.wrap(json['image']).map { |img| img.is_a?(Hash) ? img['url'] : img }.compact
          if all_images.any?
            metadata[:main_image] = all_images.first
            metadata[:images] = all_images[1..-1] if all_images.length > 1
          end

          # Extract and normalize rating data
          if json['aggregateRating']
            rating_value = json.dig('aggregateRating', 'ratingValue')
            review_count = json.dig('aggregateRating', 'reviewCount')

            metadata[:rating] = rating_value.to_f if rating_value
            metadata[:review_count] = review_count.to_i if review_count
          end

          break # Stop after finding the primary rental object
        end
      rescue JSON::ParserError
        next
      end
    end

    metadata
  end

  def parse_metadata_fallback(doc)
    host_data = extract_host(doc)
    details_data = extract_details(doc)
    images_data = extract_images(doc)

    {
      title: extract_title(doc),
      description: extract_description(doc),
      main_image: images_data[:main_image],
      images: images_data[:images],
      rating: extract_rating(doc),
      review_count: extract_review_count(doc),
      amenities: extract_amenities(doc),
      # Flatten host data
      host_image_url: host_data[:image_url],
      is_superhost: host_data[:is_superhost],
      # Flatten details data
      guests: details_data[:guests]&.to_i,
      bedrooms: details_data[:bedrooms]&.to_i,
      beds: details_data[:beds]&.to_i,
      baths: details_data[:baths]&.to_f
    }
  end

  def extract_title(doc)
    doc.at_css("meta[property='og:title']")&.[]('content') || 
    doc.at_css("title")&.text
  end

  def extract_description(doc)
    doc.at_css("meta[property='og:description']")&.[]('content') || 
    doc.at_css("meta[name='description']")&.[]('content')
  end

  def extract_images(doc)
    # Primary OG image - this will be the main_image
    main_image = doc.at_css("meta[property='og:image']")&.[]('content')

    # Additional images for gallery
    gallery_images = []

    # Try to find other images (brittle)
    doc.css('img').each do |img|
      src = img['src']
      if src && src.match?(/airbnb|vrbo/i) && !src.match?(/profile|icon|logo/i)
        # Skip the main image if we already have it
        next if main_image && src == main_image
        gallery_images << src unless gallery_images.include?(src)
      end
    end

    {
      main_image: main_image,
      images: gallery_images.take(10) # Get more gallery images
    }
  end

  def extract_host(doc)
    host_info = {
      name: nil,
      image_url: nil,
      is_superhost: false
    }

    # Generic approach: look for "Hosted by" text
    host_text_node = doc.search("[text()*='Hosted by']").first
    if host_text_node
      host_info[:name] = host_text_node.text.gsub("Hosted by", "").strip
    end
    
    host_info
  end

  def extract_details(doc)
    details = {
      guests: nil,
      bedrooms: nil,
      beds: nil,
      baths: nil
    }

    text = doc.text
    
    details[:guests] = text.match(/(\d+)\s+guests?/)&.[](1)
    details[:bedrooms] = text.match(/(\d+)\s+bedrooms?/)&.[](1)
    details[:beds] = text.match(/(\d+)\s+beds?/)&.[](1)
    details[:baths] = text.match(/(\d+(\.\d+)?)\s+baths?/)&.[](1)

    details
  end

  def extract_rating(doc)
    # Fallback if not found in JSON-LD
    rating = doc.at_css("[itemprop='ratingValue']")&.[]('content')

    unless rating
      # Look for pattern "4.9 stars"
      rating = doc.text.match(/(\d\.\d{1,2})\s+stars?/)&.[](1)
    end

    rating&.to_f
  end

  def extract_review_count(doc)
    count = doc.at_css("[itemprop='reviewCount']")&.[]('content')

    unless count
      count = doc.text.match(/(\d+)\s+reviews?/)&.[](1)
    end

    count&.to_i
  end

  def extract_amenities(doc)
    common_amenities = ["Wifi", "Kitchen", "Pool", "Hot tub", "Washer", "Dryer", "Air conditioning", "Heating", "TV"]
    found_amenities = []
    
    full_text = doc.text
    
    common_amenities.each do |amenity|
      found_amenities << amenity if full_text.include?(amenity)
    end
    
    found_amenities
  end
end