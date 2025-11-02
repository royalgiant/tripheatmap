class ClaudeAnalysisService
  MAX_RETRIES = 10
  INITIAL_DELAY = 1

  def analyze_image(image_url)
    prompt = generate_analysis_prompt
    response = call_claude_api(prompt, image_url)
    parse_claude_response(response)
  end

  private

  def generate_analysis_prompt
    <<~PROMPT
      Please analyze this selfie image for skin conditions and provide a diagnosis:
      1. Identify any visible skin conditions (e.g., acne, dryness, redness, hyperpigmentation).
      2. Describe the severity of each condition (mild, moderate, severe).
      3. Suggest potential causes (e.g., environmental factors, diet, skincare routine).
      4. Recommend skincare products and routines to treat the skin conditions. Provide specific products & brands (e.g CeraVe Moisturizing Cream, CeraVe PM Facial Cleanser, Korean skincare products, etc. that will help the user).
      5. Recommend diet plans for the user. Provide a list of specific ingredients and how they help the skin condition (e.g. leafy greens, salmon, ginger, lemons, etc.).
      6. Highlight any positive aspects of the skin (e.g., good hydration, even tone).
      Make your response concise and to the point and at a 5th grade reading level.
    PROMPT
  end

  def system_prompt
    "You are an expert dermatologist specializing in skin condition analysis from images. Provide a detailed diagnosis based on the provided selfie, including skin conditions, severity, potential causes, recommended treatments, and positive aspects of the skin."
  end

  def call_claude_api(prompt, image_url)
    client = Anthropic::Client.new
    retries = 0

    begin
      image_data = download_image(image_url)
      base64_image = Base64.strict_encode64(image_data)

      content_type = Marcel::MimeType.for(image_data)
      media_type = content_type || "image/jpeg"

      client.messages(
        parameters: {
          model: "claude-3-sonnet-20240229",
          system: system_prompt,
          messages: [
            {
              role: "user",
              content: [
                { type: "text", text: prompt },
                { type: "image", source: { type: "base64", media_type: media_type, data: base64_image } }
              ]
            }
          ],
          max_tokens: 4096
        }
      )
    rescue Faraday::TooManyRequestsError => e
      retries += 1
      if retries <= MAX_RETRIES
        delay = INITIAL_DELAY * (2 ** (retries - 1))
        Rails.logger.info "Claude API rate limit hit, retrying in #{delay}s (attempt #{retries}/#{MAX_RETRIES})"
        sleep(delay)
        retry
      else
        Rails.logger.error "Claude API max retries (#{MAX_RETRIES}) reached: #{e.message}"
        raise e
      end
    rescue StandardError => e
      Rails.logger.error "Claude API error: #{e.message}"
      raise e
    end
  end

  def download_image(image_url)
    URI.open(image_url, read_timeout: 10).read
  rescue OpenURI::HTTPError => e
    raise "Failed to download image from #{image_url}: #{e.message}"
  rescue Errno::ETIMEDOUT, Net::ReadTimeout => e
    raise "Timeout downloading image from #{image_url}: #{e.message}"
  end

  def parse_claude_response(response)
    {
      diagnosis: response["content"][0]["text"],
      timestamp: Time.current,
      model_info: {
        name: response["model"],
        usage: {
          input_tokens: response["usage"]["input_tokens"],
          output_tokens: response["usage"]["output_tokens"],
          total_tokens: response["usage"]["input_tokens"] + response["usage"]["output_tokens"]
        }
      }
    }
  end
end