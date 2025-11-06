require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do
  get 'maps/index'
  get 'maps/city/:city', to: 'maps#city', as: 'city_map'
  devise_for :users, controllers: { sessions: 'users/sessions', passwords: 'users/passwords', registrations: 'users/registrations', omniauth_callbacks: 'users/omniauth_callbacks', confirmations: 'users/confirmations' }
  get 'auth/failure', to: 'users/omniauth_callbacks#failure'
  
  devise_scope :user do
    # authentication logic routes
    get "signup", to: "devise/registrations#new"
    post "signup", to: "devise/registrations#create"
    get "login", to: "devise/sessions#new"
    post "login", to: "devise/sessions#create"
    delete "logout", to: "devise/sessions#destroy"
    post "logout", to: "devise/sessions#destroy"
    get "logout", to: "devise/sessions#destroy"
  end

  root "maps#index"

  scope controller: :static do
    get :terms
    get :privacy
    match :contact, via: [:get, :post]
  end

  namespace :api do
    namespace :v1 do
      resources :error_logs, only: [:create]
      resources :reddit_posts, only: [:index]
    end
  end

  # For sidekiq dashboard
  sidekiq_creds = Rails.application.credentials.dig(Rails.env.to_sym, :sidekiqweb)

  Sidekiq::Web.use(Rack::Auth::Basic) do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(
      ::Digest::SHA256.hexdigest(username),
      ::Digest::SHA256.hexdigest(sidekiq_creds[:username])
    ) &
    ActiveSupport::SecurityUtils.secure_compare(
      ::Digest::SHA256.hexdigest(password),
      ::Digest::SHA256.hexdigest(sidekiq_creds[:password])
    )
  end

  mount Sidekiq::Web => '/sidekiq'
  get "up" => "rails/health#show", as: :rails_health_check
end
