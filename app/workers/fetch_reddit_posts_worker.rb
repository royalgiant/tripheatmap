# frozen_string_literal: true
class FetchRedditPostsWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, queue: :default

  SUBS = %w[
    travel solotravel expats digitalnomad
    thailand mexico philippines colombia europe
  ].freeze

  TERMS = [
    "bribe", "mordida", "extort", "police corruption",
    "shakedown", "checkpoint fine", "gang", "cartel",
    "drugs", "homeless"
  ].freeze

  def perform
    SUBS.each do |subreddit|
      TERMS.each do |term|
        RedditClient.search(subreddit: subreddit, query: term, limit: 25).each do |p|
          save_post(p)
        end
      end
    end
  rescue => e
    Rails.logger.error("FetchRedditPostsWorker error: #{e.message}")
  end

  private

  def save_post(post)
    RedditPost.find_or_create_by!(post_id: post["id"]) do |rp|
      rp.subreddit   = post["subreddit"]
      rp.title       = post["title"]
      rp.selftext    = post["selftext"]
      rp.url         = "https://reddit.com#{post["permalink"]}"
      rp.created_utc = Time.at(post["created_utc"]) rescue Time.current
      rp.status      = "pending"
    end
  rescue => e
    Rails.logger.error("Failed to save Reddit post #{post["id"]}: #{e.message}")
  end
end
