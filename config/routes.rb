Rails.application.routes.draw do
  devise_for :users

  get "home/index"
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  root "home#index"

  namespace :enedis do
    resources :consumptions, only: [ :index, :show ] do
      collection do
        get :daily
        get :monthly
      end
    end
  end

  # Routes pour le mock controller
  get "/mock/oauth_callback", to: "enedis/mock#oauth_callback", as: :oauth_callback_mock

  # Routes OAuth avec resources
  resource :oauth, only: [], controller: "enedis/oauth" do
    get :authorize
    get :callback
  end
end
