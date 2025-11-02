# config/initializers/redis.rb
if Rails.env.production? && ENV['REDIS_URL'].present?
  Rails.logger.info("Redis is in production")
  uri = URI.parse(ENV['REDIS_URL'])
  Redis.current = Redis.new(url: ENV['REDIS_URL'])
else
  Rails.logger.info("Redis is in development")
  REDIS = Redis.new(host: '127.0.0.1', port: 6379, db: 0)
end
