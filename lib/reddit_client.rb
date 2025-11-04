require "faraday"
require "json"
require "base64"

class RedditClient
  BASE_URL = "https://oauth.reddit.com"
  TOKEN_URL = "https://www.reddit.com/api/v1/access_token"

  class << self
    def search(subreddit:, query:, limit: 50)
      conn = Faraday.new(url: BASE_URL, headers: headers)
      response = conn.get("/r/#{subreddit}/search", {
        q: query,
        restrict_sr: 1,
        sort: "new",
        t: "year",
        limit: limit,
        syntax: "cloudsearch"
      })

      if response.status == 200
        json = JSON.parse(response.body)
        posts = (json.dig("data", "children") || []).map { |c| c["data"] }
        Rails.logger.info("[RedditClient] ✅ Found #{posts.size} posts in /r/#{subreddit} for '#{query}'")
        posts
      else
        Rails.logger.warn("[RedditClient] ⚠️ API error #{response.status}: #{response.body.truncate(300)}")
        []
      end
    rescue => e
      Rails.logger.error("[RedditClient] ❌ search error: #{e.message}")
      []
    end

    private

    def headers
      {
        "Authorization" => "Bearer #{access_token}",
        "User-Agent" => credentials[:user_agent]
      }
    end

    def credentials
      @credentials ||= Rails.application.credentials.dig(Rails.env.to_sym, :reddit).transform_keys(&:to_sym)
    end

    def access_token
      # Cached in-memory until expiration
      if @access_token && @token_expires_at && Time.now < @token_expires_at
        return @access_token
      end

      conn = Faraday.new(url: TOKEN_URL)
      auth_header = "Basic #{Base64.strict_encode64("#{credentials[:client_id]}:#{credentials[:client_secret]}")}"
      response = conn.post(nil, { grant_type: "client_credentials" }, {
        "Authorization" => auth_header,
        "User-Agent" => credentials[:user_agent]
      })

      if response.status == 200
        json = JSON.parse(response.body)
        @access_token = json["access_token"]
        @token_expires_at = Time.now + json["expires_in"].to_i.seconds
        Rails.logger.info("[RedditClient] 🔐 New access token fetched, expires in #{json['expires_in']}s")
        @access_token
      else
        Rails.logger.error("[RedditClient] ❌ Token fetch failed (#{response.status}): #{response.body.truncate(300)}")
        nil
      end
    rescue => e
      Rails.logger.error("[RedditClient] ❌ OAuth token error: #{e.message}")
      nil
    end
  end
end
