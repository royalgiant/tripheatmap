Anthropic.configure do |config|
  config.access_token = Rails.application.credentials.dig(Rails.env.to_sym, :anthropic, :api_key)
end