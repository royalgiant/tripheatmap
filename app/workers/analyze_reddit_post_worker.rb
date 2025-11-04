class AnalyzeRedditPostWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, queue: :nlp

  def perform(post_id)
    post = RedditPost.find_by(id: post_id)
    return unless post&.pending?

    unless openai_enabled?
      Rails.logger.error "[AnalyzeRedditPostWorker] ❌ OpenAI not configured"
      post.update(status: "error")
      return
    end

    # Build full text with subreddit context
    text = [post.title, post.selftext].join("\n\n")
    
    # Use subreddit name as location hint (e.g. r/Cancun, r/Bangkok)
    subreddit_hint = extract_location_from_subreddit(post.subreddit)

    # Analyze with OpenAI (does EVERYTHING: location extraction + risk analysis)
    result = OpenaiAnalysisService.analyze_travel_incident(
      post_text: text,
      city: subreddit_hint[:city],
      country: subreddit_hint[:country]
    )

    # Update post with all analysis results
    post.update!(
      city: result[:city],
      neighborhood: result[:neighborhood],
      country: result[:country],
      lat: result[:latitude],
      lon: result[:longitude],
      confidence: result[:confidence],
      risk_score: result[:risk_score],
      risk_level: result[:risk_level],
      incident_type: result[:incident_type],
      summary: result[:summary],
      status: result[:relevant] ? "analyzed" : "skipped"
    )

    location = [result[:neighborhood], result[:city], result[:country]].compact.join(", ")
    Rails.logger.info "[AnalyzeRedditPostWorker] ✅ Post #{post.id} → #{result[:risk_level]} (#{result[:incident_type]}) in #{location} - #{result[:usage][:total_tokens]} tokens"
  rescue => e
    Rails.logger.error "[AnalyzeRedditPostWorker] ❌ #{e.class}: #{e.message}"
    post&.update(status: "error") rescue nil
  end

  private

  def openai_enabled?
    Rails.application.credentials.dig(Rails.env.to_sym, :openai, :access_token).present?
  end

  # Extract location hints from subreddit names
  def extract_location_from_subreddit(subreddit)
    # Map common location subreddits to their actual locations
    location_map = {
      'cancun' => { city: 'Cancun', country: 'Mexico' },
      'tulum' => { city: 'Tulum', country: 'Mexico' },
      'playadelcarmen' => { city: 'Playa del Carmen', country: 'Mexico' },
      'mexicocity' => { city: 'Mexico City', country: 'Mexico' },
      'tijuana' => { city: 'Tijuana', country: 'Mexico' },
      'brasil' => { city: nil, country: 'Brazil' },
      'riodejaneiro' => { city: 'Rio de Janeiro', country: 'Brazil' },
      'argentina' => { city: nil, country: 'Argentina' },
      'buenosaires' => { city: 'Buenos Aires', country: 'Argentina' },
      'medellin' => { city: 'Medellin', country: 'Colombia' },
      'cartagena' => { city: 'Cartagena', country: 'Colombia' },
      'colombia' => { city: nil, country: 'Colombia' },
      'bolivia' => { city: nil, country: 'Bolivia' },
      'bali' => { city: 'Bali', country: 'Indonesia' },
      'indonesia' => { city: nil, country: 'Indonesia' },
      'thailand' => { city: nil, country: 'Thailand' },
      'bangkok' => { city: 'Bangkok', country: 'Thailand' },
      'vietnam' => { city: nil, country: 'Vietnam' },
      'philippines' => { city: nil, country: 'Philippines' },
      'manila' => { city: 'Manila', country: 'Philippines' },
      'india' => { city: nil, country: 'India' },
      'mumbai' => { city: 'Mumbai', country: 'India' },
      'delhi' => { city: 'Delhi', country: 'India' },
      'egypt' => { city: nil, country: 'Egypt' },
      'kenya' => { city: nil, country: 'Kenya' },
      'nigeria' => { city: nil, country: 'Nigeria' },
      'morocco' => { city: nil, country: 'Morocco' },
      'romania' => { city: nil, country: 'Romania' },
      'bulgaria' => { city: nil, country: 'Bulgaria' },
      'albania' => { city: nil, country: 'Albania' }
    }

    normalized = subreddit.downcase.gsub(/^r\//, '')
    location_map[normalized] || { city: nil, country: nil }
  end
end
