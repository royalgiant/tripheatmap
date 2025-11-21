class AiContentGenerator
  # Generate all content for a single neighborhood
  def self.generate_neighborhood_content(neighborhood:, stats:, city_name:, state: nil, country: nil, total_neighborhoods:)
    new.generate_neighborhood_content(
      neighborhood: neighborhood,
      stats: stats,
      city_name: city_name,
      state: state,
      country: country,
      total_neighborhoods: total_neighborhoods
    )
  end

  def generate_neighborhood_content(neighborhood:, stats:, city_name:, state: nil, country: nil, total_neighborhoods:)
    location = [city_name, state, country].compact.join(", ")

    prompt = <<~PROMPT
      You are a travel content writer and SEO specialist creating content for a neighborhood in #{city_name}.

      CITY: #{location}
      TOTAL NEIGHBORHOODS ANALYZED: #{total_neighborhoods}

      NEIGHBORHOOD:
      - Name: #{neighborhood.name}
      - Restaurants: #{stats[:restaurant_count] || 0}
      - Cafés: #{stats[:cafe_count] || 0}
      - Bars: #{stats[:bar_count] || 0}
      - Vibrancy Score: #{stats[:vibrancy_index]&.round(1) || 'N/A'} / 10
      - Area: #{neighborhood.read_attribute(:area_sq_km)&.round(2) || 'N/A'} km²

      Generate the following content:

      1. NEIGHBORHOOD DESCRIPTION (100-150 words):
         - Compelling 2-3 sentence description for #{neighborhood.name}
         - Focus on what makes it appealing for visitors/travelers
         - Naturally incorporate statistics (restaurant count, vibrancy, amenities)
         - Use active, engaging language
         - Optimize for SEO keywords: "where to stay", "best neighborhood", "restaurants", "nightlife"
         - Be specific and data-driven

      2. ABOUT (150-200 words):
         - About #{neighborhood.name} neighborhood
         - What makes this neighborhood unique
         - Culture, vibe, atmosphere
         - Who would enjoy staying here

      3. BEST TIME TO VISIT (120-150 words):
         - Best time to visit #{neighborhood.name}
         - Seasonal considerations for this area
         - Local events or festivals in this neighborhood

      4. GETTING AROUND (120-150 words):
         - Getting around #{neighborhood.name}
         - Transit options from/to this neighborhood
         - Walkability within the neighborhood
         - Parking, bike rentals, local transportation tips

      TONE: Informative, helpful, data-driven but engaging

      Return ONLY valid JSON (no markdown, no code blocks):
      {
        "description": "neighborhood description...",
        "about": "about this neighborhood...",
        "time_to_visit": "best time to visit this neighborhood...",
        "getting_around": "getting around this neighborhood..."
      }
    PROMPT

    response = call_openai_api(prompt, max_tokens: 2500)
    parse_json_response(response)
  rescue => e
    Rails.logger.error "OpenAI API error generating neighborhood content: #{e.message}"
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
        model: "gpt-4.1-nano",
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

    content = response.dig("choices", 0, "message", "content")
    return nil unless content

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
    Rails.logger.error "Failed to parse JSON response: #{e.message}"
    nil
  end

  def parse_text_response(response)
    return nil unless response

    content = response.dig("choices", 0, "message", "content")
    content&.strip
  end
end
