source "https://rubygems.org"
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby "3.3.5"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.1.4"
gem 'railties', '~> 7.1.4'
gem 'faraday'
gem 'devise'
gem 'omniauth'
gem 'omniauth-google-oauth2'
gem 'omniauth-rails_csrf_protection', "~> 1.0"
gem 'select2-rails'
gem 'kamal'

# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"

# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"

# Use the Puma web server [https://github.com/puma/puma]
gem "puma", "~> 6.0"

# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"

# Use SCSS for stylesheets
gem "sass-rails", "~> 6"

# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"

# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"

# Use Redis adapter to run Action Cable in production
gem "redis", "~> 4.0"

# Use hiredis to get better performance than the "redis" gem
gem 'hiredis'

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.7"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ mingw mswin x64_mingw jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap"

#Rack CORs
gem 'rack-cors'

#Rake
gem 'rake', '~> 13.0', '>= 13.0.6'

# Use Sass to process CSS
# gem "sassc-rails"

gem 'json', '~> 2.5', '>= 2.5.0'

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "aws-sdk-s3"

gem 'mocha'

gem 'stripe'

# AI
gem "ruby-openai"
gem 'ruby-anthropic'

# Sitemap
gem 'sitemap_generator'

# Simple, efficient background processing using Redis.
# https://github.com/sidekiq/sidekiq
gem "sidekiq", "~> 7.2.2"
# gem "sidekiq-cron", "~> 1.12"
# Tailwind CSS
gem "tailwindcss-rails"
gem 'premailer-rails'

# For making concurrent requests
gem 'concurrent-ruby', require: 'concurrent'

# Mailgun
gem 'mailgun-ruby', '~>1.2.14'

gem 'roo', '~> 2.10'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri mingw x64_mingw ]
  gem 'pry'
  gem 'pry-byebug'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'shoulda-context', '~> 1.2', '>= 1.2.2'
  gem 'rails-controller-testing'
  gem 'listen', '~> 3.8'
end

group :development do
  # Use console on exceptions pages [https://github.com/rails/web-console]
  gem "web-console"

  # Add speed badges [https://github.com/MiniProfiler/rack-mini-profiler]
  # gem "rack-mini-profiler"

  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem "spring"

  gem 'foreman', '~> 0.87.2'
end

group :test do
  # Use system testing [https://guides.rubyonrails.org/testing.html#system-testing]
  gem "capybara"
  gem "selenium-webdriver"
  gem "webdrivers"
  gem 'rspec-rails'
  gem 'simplecov', require: false
  gem 'database_cleaner-active_record'
end

gem "httparty", "~> 0.22.0"
gem "attr_encrypted", "~> 4.2"
gem "csv", "~> 3.3"
gem "uuidtools", "~> 2.2"
