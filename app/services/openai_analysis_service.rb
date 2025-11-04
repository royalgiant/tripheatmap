class OpenaiAnalysisService
  MAX_RETRIES = 3
  INITIAL_DELAY = 2

  def self.analyze_travel_incident(post_text:, city: nil, country: nil)
    new.analyze_travel_incident(post_text: post_text, city: city, country: country)
  end

  def analyze_travel_incident(post_text:, city: nil, country: nil)
    prompt = generate_travel_incident_prompt(post_text, city, country)
    response = call_openai_api(prompt)
    parse_travel_response(response)
  end

  private

  def generate_travel_incident_prompt(post_text, city, country)
    location_hint = [city, country].compact.join(", ")
    location_info = location_hint.present? ? "\n\nSubreddit Context: #{location_hint}" : ""

    <<~PROMPT
      You are a travel safety analyst. Analyze this Reddit post about a traveler's experience.

      POST TO ANALYZE:
      #{post_text}#{location_info}

      YOUR TASK:
      1. Extract the LOCATION (city and country) where the incident occurred
      2. Determine if this describes a REAL safety incident (not advice, hypotheticals, or questions)
      3. Assess the severity and type of incident
      4. Generate a concise summary for content marketing
      5. Rate the risk level

      LOCATION EXTRACTION:
      - Extract the specific city, neighborhood, and country mentioned in the post
      - If subreddit is location-specific (e.g. r/Cancun, r/Bangkok), use that as context
      - Neighborhood should be a specific district/area within the city (e.g. "Zona Hotelera", "Sukhumvit", "Old Town")
      - If only country mentioned, leave city and neighborhood as null
      - Return null for fields if not found in the post

      RISK LEVELS:
      - safe (0.0-0.33): Minor inconvenience, avoided scam, general advice, no actual incident
      - caution (0.34-0.66): Successful scam, bribery, petty theft, threatening behavior
      - dangerous (0.67-1.0): Violent crime, armed robbery, assault, kidnapping, major extortion

      INCIDENT TYPES (choose most specific):
      - police_bribery: Police/official demanding bribes
      - checkpoint_extortion: Forced payment at checkpoints/borders
      - taxi_scam: Overcharging, fake meters, kidnapping by taxi
      - rental_scam: Car rental scams, fake damage claims
      - theft: Pickpocketing, bag snatching, non-violent theft
      - armed_robbery: Robbery with weapons, ATM at gunpoint
      - assault: Physical violence, attack
      - drug_plant: Planted drugs, fake charges
      - accommodation_scam: Hotel/hostel scams
      - vendor_scam: Tourist trap scams, overcharging
      - other: Doesn't fit above categories

      Return ONLY valid JSON (no markdown, no code blocks):
      {
        "relevant": true/false,
        "city": "Bangkok" or null,
        "neighborhood": "Sukhumvit" or null,
        "country": "Thailand" or null,
        "latitude": 13.7563 or null,
        "longitude": 100.5018 or null,
        "risk_score": 0.0-1.0,
        "risk_level": "safe"/"caution"/"dangerous",
        "incident_type": "police_bribery"/"checkpoint_extortion"/etc,
        "confidence": 0.0-1.0,
        "summary": "One sentence summary focusing on what happened, where, and outcome. Must be engaging for content marketing."
      }

      RULES:
      - Always extract city and country even if post is not a real incident.
      - If NOT a real incident (advice, question, hypothetical), set relevant=false, but still provide the most likely city and country.
      - risk_score=0.0 and risk_level="safe" for these.
      - A post is only irrelevant if it cannot be confidently mapped to any specific city or country.
      - For latitude/longitude, use approximate coordinates for the city (you have world knowledge of major cities)
      - If you don't know exact coordinates, leave them as null
      - Summary should be compelling and specific (e.g. "Traveler extorted for $500 by corrupt police at Bangkok checkpoint after fake traffic violation")
      - Confidence reflects certainty about the incident AND location details
      - Be consistent: risk_score must align with risk_level thresholds
    PROMPT
  end

  def system_prompt
    "You are an expert travel safety analyst specializing in identifying and categorizing safety incidents from traveler reports. You provide structured analysis in JSON format."
  end

  def call_openai_api(prompt)
    client = OpenAI::Client.new
    retries = 0

    begin
      client.chat(
        parameters: {
          model: "gpt-5-nano", # Cheapest and fastest
          messages: [
            { role: "system", content: system_prompt },
            { role: "user", content: prompt }
          ],
          temperature: 0.3, # Lower = more consistent
          max_tokens: 500
        }
      )
    rescue Faraday::TooManyRequestsError => e
      retries += 1
      if retries <= MAX_RETRIES
        delay = INITIAL_DELAY * (2 ** (retries - 1))
        Rails.logger.info "OpenAI API rate limit hit, retrying in #{delay}s (attempt #{retries}/#{MAX_RETRIES})"
        sleep(delay)
        retry
      else
        Rails.logger.error "OpenAI API max retries (#{MAX_RETRIES}) reached: #{e.message}"
        raise e
      end
    rescue StandardError => e
      Rails.logger.error "OpenAI API error: #{e.message}"
      raise e
    end
  end

  def parse_travel_response(response)
    content = response.dig("choices", 0, "message", "content")
    parsed_content = nil

    if content
      json_string = nil

      # Extract from markdown block if present
      if content.include?('```json')
        json_match = content.match(/```json\s*(\{.*?\})\s*```/m)
        json_string = json_match[1] if json_match
      elsif content.include?('```')
        json_match = content.match(/```\s*(\{.*?\})\s*```/m)
        json_string = json_match[1] if json_match
      else
        json_string = content.strip
      end

      if json_string
        begin
          parsed_content = JSON.parse(json_string)
        rescue JSON::ParserError => e
          Rails.logger.warn "Initial JSON parse failed: #{e.message}"
          
          # Try sanitizing (in case of Ruby-style hash)
          sanitized = json_string
                        .gsub(/=>/, ':')
                        .gsub(/nil/, 'null')
                        .gsub(/:(\s)?([a-zA-Z_][a-zA-Z0-9_]*)/, ':"\\2"')
          begin
            parsed_content = JSON.parse(sanitized)
          rescue JSON::ParserError => fallback_error
            Rails.logger.error "Sanitized parse failed: #{fallback_error.message}"
            parsed_content = fallback_response
          end
        end
      end
    end

    # Return parsed content with symbolized keys
    result = (parsed_content || fallback_response).symbolize_keys

    # Add token usage info
    result[:usage] = {
      prompt_tokens: response.dig("usage", "prompt_tokens"),
      completion_tokens: response.dig("usage", "completion_tokens"),
      total_tokens: response.dig("usage", "total_tokens")
    }

    result
  end

  def fallback_response
    {
      relevant: false,
      city: nil,
      neighborhood: nil,
      country: nil,
      latitude: nil,
      longitude: nil,
      risk_score: 0.0,
      risk_level: "safe",
      incident_type: "unknown",
      confidence: 0.0,
      summary: "Analysis failed - unable to process post"
    }
  end
end
