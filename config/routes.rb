require 'sidekiq/web'
require 'sidekiq/cron/web'

Rails.application.routes.draw do
  get 'best-luxury-hotels', to: 'best_luxury_hotel#index', as: 'best_luxury_hotels_index'
  get 'best-luxury-hotels-in-:city', to: 'best_luxury_hotel#show', as: 'best_luxury_hotels'
  get 'best-boutique-hotels', to: 'best_boutique_hotel#index', as: 'best_boutique_hotels_index'
  get 'best-boutique-hotels-in-:city', to: 'best_boutique_hotel#show', as: 'best_boutique_hotels'
  get 'best-cheap-hotels', to: 'best_cheap_hotel#index', as: 'best_cheap_hotels_index'
  get 'best-cheap-hotels-in-:city', to: 'best_cheap_hotel#show', as: 'best_cheap_hotels'
  get 'best-affordable-hotels', to: 'best_cheap_hotel#index', as: 'best_affordable_hotels_index'
  get 'best-affordable-hotels-in-:city', to: 'best_cheap_hotel#show', as: 'best_affordable_hotels'
  get 'best-budget-hotels', to: 'best_cheap_hotel#index', as: 'best_budget_hotels_index'
  get 'best-budget-hotels-in-:city', to: 'best_cheap_hotel#show', as: 'best_budget_hotels'
  get 'hotels-in-:city-near-:neighborhood', to: 'hotels_near#show', as: 'hotels_near'
  get 'hotels-near-major-airports', to: 'hotels_near_airport#index', as: 'hotels_near_airport_index'
  get 'hotels-near-airports-in-:city', to: 'hotels_near_airport#city', as: 'hotels_near_airport_city'
  get 'hotels-near-airport-:airport-in-:city', to: 'hotels_near_airport#show', as: 'hotels_near_airport'
  get 'hotels-near-:slug-airport', to: 'hotels_near_airport#show_smart', as: 'hotels_near_smart_airport'
  get 'hotels-near-major-universities', to: 'hotels_near_university#index', as: 'hotels_near_university_index'
  get 'hotels-near-universities-in-:city', to: 'hotels_near_university#city', as: 'hotels_near_university_city'
  get 'hotels-near-university-:university-in-:city', to: 'hotels_near_university#show', as: 'hotels_near_university'
  get 'hotels-near-:slug-university', to: 'hotels_near_university#show_smart', as: 'hotels_near_smart_university'
  get 'hotels-near-landmarks', to: 'hotels_near_landmark#index', as: 'hotels_near_landmark_index'
  get 'hotels-near-landmarks-in-:city', to: 'hotels_near_landmark#city', as: 'hotels_near_landmark_city'
  get 'hotels-near-:landmark-in-:city', to: 'hotels_near_landmark#show', as: 'hotels_near_landmark'
  get 'best-neighborhoods', to: 'best_neighborhood#index', as: 'best_neighborhood_index'
  get 'best-neighborhood-in-:city', to: 'best_neighborhood#show', as: 'best_neighborhood'
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
