class AiContentGenerator
  # Generate all content for a single neighborhood
  def self.generate_neighborhood_content(neighborhood:, stats:, city_name:, state: nil, country: nil, total_neighborhoods:)
    if neighborhood.name.include?("Tract")
      return nil
    end

    if stats[:vibrancy_index].nil? || stats[:vibrancy_index] <= 4.0
      return nil
    end

    new.generate_neighborhood_content(
      neighborhood: neighborhood,
      stats: stats,
      city_name: city_name,
      state: state,
      country: country,
      total_neighborhoods: total_neighborhoods
    )
  end

  def self.generate_place_content(place:, neighborhood:)
    if neighborhood.name.include?("Tract")
      return nil
    end

    new.generate_place_content(place: place, neighborhood: neighborhood)
  end

  def generate_neighborhood_content(neighborhood:, stats:, city_name:, state: nil, country: nil, total_neighborhoods:)
    location = [city_name, state, country].compact.join(", ")

    prompt = <<~PROMPT
      Neighborhood: #{neighborhood.name}, #{location}
      Total neighborhoods: #{total_neighborhoods}
      Restaurants: #{stats[:restaurant_count] || 0}, Cafés: #{stats[:cafe_count] || 0}, Bars: #{stats[:bar_count] || 0}
      Vibrancy: #{stats[:vibrancy_index]&.round(1) || 'N/A'}/10, Area: #{neighborhood.read_attribute(:area_sq_km)&.round(2) || 'N/A'} km²

      Generate JSON:
      - description (50-75 words): Compelling overview, incorporate stats, SEO optimized
      - about (75-100 words): Unique features, culture, vibe, ideal visitor
      - time_to_visit (60-80 words): Seasonal tips, local events
      - getting_around (60-80 words): Transit, walkability, parking

      {"description":"...","about":"...","time_to_visit":"...","getting_around":"..."}
    PROMPT

    # gpt-5-nano is a reasoning model - needs extra tokens for reasoning + output
    response = call_openai_api(prompt, max_tokens: 8000)
    parse_json_response(response)
  rescue => e
    Rails.logger.error "OpenAI API error generating neighborhood content: #{e.message}"
    nil
  end

  def generate_place_content(place:, neighborhood:)
    prompt = <<~PROMPT
      Place: #{place.name} (#{place.place_type})
      Address: #{place.address || 'N/A'}
      Tags: #{place.tags.present? ? place.tags.to_json : 'N/A'}
      Location: #{neighborhood.name}, #{neighborhood.city}, #{neighborhood.state}, #{neighborhood.country}

      Return JSON:
      - rating: 1.0-5.0 (0.5 steps)
      - price_range: $, $$, $$$, or $$$$
      - category: "luxury", "boutique", or null
      - average_price: USD/night estimate
      - image_url: public URL or null

      {"rating":4.0,"price_range":"$$","category":"boutique","average_price":120.00,"image_url":null}
    PROMPT
    # gpt-5-nano is a reasoning model - needs extra tokens for reasoning + output
    response = call_openai_api(prompt, max_tokens: 2500)
    parse_json_response(response)
  rescue => e
    Rails.logger.error "OpenAI API error generating place content: #{e.message}"
    nil
  end

  private

  def system_prompt
    "You are an expert travel writer and SEO specialist who creates practical, engaging content for travelers. You focus on actionable information and authentic insights."
  end

  def call_openai_api(prompt, max_tokens: 500)
    client = OpenAI::Client.new

    client.chat(
      parameters: {
        model: "gpt-5-nano",
        messages: [
          { role: "system", content: system_prompt },
          { role: "user", content: prompt }
        ],
        max_completion_tokens: max_tokens,
        response_format: { type: "json_object" }
      }
    )
  end

  def parse_json_response(response)
    return nil unless response

    if response["error"]
      Rails.logger.error "OpenAI API error: #{response['error']}"
      return nil
    end

    finish_reason = response.dig("choices", 0, "finish_reason")
    if finish_reason && finish_reason != "stop"
      Rails.logger.warn "OpenAI finish_reason: #{finish_reason}"
    end

    content = response.dig("choices", 0, "message", "content")
    
    if content.nil? || content.strip.empty?
      Rails.logger.error "OpenAI returned empty content. Full response: #{response.to_json}"
      return nil
    end

    json_string = content.strip

    # Remove markdown code blocks if present
    if json_string.include?('```json')
      json_match = json_string.match(/```json\s*(\{.*?\})\s*```/m)
      json_string = json_match[1] if json_match
    elsif json_string.include?('```')
      json_match = json_string.match(/```\s*(\{.*?\})\s*```/m)
      json_string = json_match[1] if json_match
    end

    JSON.parse(json_string).symbolize_keys
  rescue JSON::ParserError => e
    Rails.logger.error "Failed to parse JSON response: #{e.message}. Content was: #{content&.truncate(500)}"
    nil
  end

  def parse_text_response(response)
    return nil unless response

    content = response.dig("choices", 0, "message", "content")
    content&.strip
  end
end