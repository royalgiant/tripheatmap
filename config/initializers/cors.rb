Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins Rails.env.production? ? ['yourdomain.com', 'https://yourdomain.com', ->(origin) { origin.nil? }] : '*'
    resource '/api/*', headers: :any, methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end