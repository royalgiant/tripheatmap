# config/initializers/sidekiq.rb
require 'sidekiq'
# require 'sidekiq-cron'

redis_config = Rails.env.development? ? { url: "redis://localhost:6379/1" } : { url: ENV['REDIS_URL'] }
Sidekiq.configure_server do |config|
  config.redis = redis_config
end

Sidekiq.configure_client do |config|
  config.redis = redis_config
end

# sidekiq_config = YAML.load_file(Rails.root.join('config', 'sidekiq.yml'))
# schedule_file = sidekiq_config.dig(:schedule, :schedule_file)
# if schedule_file && File.exist?(Rails.root.join(schedule_file)) && Sidekiq.server?
#   Sidekiq::Cron::Job.load_from_hash YAML.load_file(Rails.root.join(schedule_file))
# end