require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do
  scope 'best', as: 'best' do
    get 'luxury-hotels', to: 'best_luxury_hotel#index', as: 'luxury_hotels_index'
    get 'luxury-hotels/:city', to: 'best_luxury_hotel#show', as: 'luxury_hotels'

    get 'boutique-hotels', to: 'best_boutique_hotel#index', as: 'boutique_hotels_index'
    get 'boutique-hotels/:city', to: 'best_boutique_hotel#show', as: 'boutique_hotels'

    get 'cheap-hotels', to: 'best_cheap_hotel#index', as: 'cheap_hotels_index'
    get 'cheap-hotels/:city', to: 'best_cheap_hotel#show', as: 'cheap_hotels'
    get 'affordable-hotels', to: 'best_cheap_hotel#index', as: 'affordable_hotels_index'
    get 'affordable-hotels/:city', to: 'best_cheap_hotel#show', as: 'affordable_hotels'
    get 'budget-hotels', to: 'best_cheap_hotel#index', as: 'budget_hotels_index'
    get 'budget-hotels/:city', to: 'best_cheap_hotel#show', as: 'budget_hotels'

    get 'neighborhoods', to: 'best_neighborhood#index', as: 'neighborhood_index'
    get 'neighborhoods/:city', to: 'best_neighborhood#show', as: 'neighborhood'
  end

  get 'hotels-in-:city-near-:neighborhood', to: 'hotels_near#show', as: 'hotels_near'
  
  scope 'hotels-near', as: 'hotels_near' do
    get 'airports', to: 'hotels_near_airport#index', as: 'airport_index'
    get 'airports/:city', to: 'hotels_near_airport#city', as: 'airport_city'
    get 'airports/:city/:airport', to: 'hotels_near_airport#show', as: 'airport'

    get 'universities', to: 'hotels_near_university#index', as: 'university_index'
    get 'universities/:city', to: 'hotels_near_university#city', as: 'university_city'
    get 'universities/:city/:university', to: 'hotels_near_university#show', as: 'university'

    get 'convention-centers', to: 'hotels_near_convention_center#index', as: 'convention_center_index'
    get 'convention-centers/:city', to: 'hotels_near_convention_center#city', as: 'convention_center_city'
    get 'convention-centers/:city/:convention_center', to: 'hotels_near_convention_center#show', as: 'convention_center'

    get 'landmarks', to: 'hotels_near_landmark#index', as: 'landmark_index'
    get 'landmarks/:city', to: 'hotels_near_landmark#city', as: 'landmark_city'
    get 'landmarks/:city/:landmark', to: 'hotels_near_landmark#show', as: 'landmark'
  end
  
  resources :places, only: [:show], param: :slug do
    collection do
      get :close
    end
  end

  resources :favorites, only: [:index, :create, :destroy]
  resources :neighborhoods, only: [:show], param: :slug
  get 'maps/index'
  get 'maps/city/:city', to: 'maps#city', as: 'city_map'
  get 'maps/places/:city', to: 'maps#places', as: 'places_map'
  get 'maps/places', to: 'maps#places'
  get 'where-to-stay', to: 'where_to_stay#index', as: 'where_to_stay_index'
  get 'where-to-stay/:city', to: 'where_to_stay#show', as: 'where_to_stay'
  devise_for :users, controllers: { sessions: 'users/sessions', passwords: 'users/passwords', registrations: 'users/registrations', omniauth_callbacks: 'users/omniauth_callbacks', confirmations: 'users/confirmations' }
  get 'auth/failure', to: 'users/omniauth_callbacks#failure'
  get 'pricing', to: 'pricing#index'
  
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

  root "where_to_stay#index"

  scope controller: :static do
    get :terms
    get :privacy
    get :about
    match :contact, via: [:get, :post]
  end

  namespace :api do
    namespace :v1 do
      resources :error_logs, only: [:create]
      resources :reddit_posts, only: [:index]
      resources :neighborhoods, only: [:index, :show]
      resources :cities, only: [:index]
    end
  end

  namespace :purchase do
    resources :checkouts
    get "success", to: "checkouts#success"
  end
  resources :webhooks, only: :create
  resources :subscriptions
  resources :billings, only: :create
  resources :rentals

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
