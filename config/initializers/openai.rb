OpenAI.configure do |config|
  config.access_token = Rails.application.credentials.dig(Rails.env.to_sym, :openai, :access_token)
end