class FetchRedditPostsWorker
  include Sidekiq::Worker
  sidekiq_options retry: 3, queue: :default

  SUBREDDITS = %w[
    Cancun
    Tulum
    playadelcarmen
    MexicoCity
    tijuana
    brasil
    riodejaneiro
    argentina
    BuenosAires
    Medellin
    cartagena
    Colombia
    bolivia
    bali
    indonesia
    Thailand
    Bangkok
    vietnam
    Philippines
    Manila
    india
    mumbai
    delhi
    egypt
    Kenya
    Nigeria
    Morocco
    romania
    bulgaria
    albania
    travel
    solotravel
    digitalnomad
    backpacking
  ].freeze
  
  #QUERY = "bribe OR bribery OR extortion OR extorted OR shakedown OR corruption OR scam OR fraud OR stolen OR theft OR robbery OR mugging OR pickpocket OR \"police bribe\" OR \"police extortion\" OR \"cop bribe\" OR \"dangerous area\" OR \"safe area\" OR \"unsafe area\" OR \"extortion attempt\" OR \"take me to jail\" OR \"at gunpoint\""
  QUERY = "(bribe OR bribery OR extortion OR scam* OR fraud OR rob* OR unsafe OR danger* OR avoid*)"

  # Reddit API: 100 requests/minute max. We use 60/minute (1 per second) to be safe
  RATE_LIMIT_DELAY = 1.0 # seconds between requests

  def perform
    start_time = Time.current
    total_posts_saved = 0
    total_posts_skipped = 0
    
    Rails.logger.info "[FetchRedditPostsWorker] 🔍 Starting fetch from #{SUBREDDITS.count} subreddits"
    Rails.logger.info "[FetchRedditPostsWorker] ⏱️  Rate limit: 1 request per #{RATE_LIMIT_DELAY}s (#{60 / RATE_LIMIT_DELAY}/min)"

    # Flatten work into single array to avoid O(n²) nested loops
    SUBREDDITS.each_with_index do |subreddit, index|
      request_start = Time.current
      
      begin
        posts = RedditClient.search(subreddit: subreddit, query: QUERY, limit: 20)
        
        new_posts = 0
        duplicates = 0
        posts.each do |post|
          if save_post(post)
            new_posts += 1
            total_posts_saved += 1
          else
            duplicates += 1
            total_posts_skipped += 1
          end
        end
        
        Rails.logger.info "[FetchRedditPostsWorker] ✅ #{index + 1}/#{SUBREDDITS.count} #{subreddit}: #{new_posts} new, #{duplicates} duplicates"
      rescue => e
        Rails.logger.error "[FetchRedditPostsWorker] ❌ #{subreddit} failed: #{e.message}"
      end
      
      # Rate limiting: ensure at least RATE_LIMIT_DELAY seconds between requests
      elapsed = Time.current - request_start
      if elapsed < RATE_LIMIT_DELAY
        sleep_time = RATE_LIMIT_DELAY - elapsed
        sleep(sleep_time)
      end
    end

    total_time = (Time.current - start_time).round(2)
    Rails.logger.info "[FetchRedditPostsWorker] ✅ Completed: #{total_posts_saved} new posts, #{total_posts_skipped} duplicates in #{total_time}s"
  end

  private

  def save_post(post)
    return false if RedditPost.exists?(post_id: post["id"])

    reddit_post = RedditPost.create!(
      post_id: post["id"],
      subreddit: post["subreddit"],
      title: post["title"],
      selftext: post["selftext"],
      url: "https://reddit.com#{post["permalink"]}",
      created_utc: Time.at(post["created_utc"]),
      status: "pending"
    )

    AnalyzeRedditPostWorker.perform_async(reddit_post.id)
    reddit_post
  rescue => e
    Rails.logger.error "[FetchRedditPostsWorker] ❌ Failed to save post #{post["id"]}: #{e.message}"
    false
  end
end
