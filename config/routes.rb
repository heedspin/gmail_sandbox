Rails.application.routes.draw do
  devise_for(:users, 
    controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }, 
    path_names: { 
      sign_in: 'login', 
      sign_out: 'logout', 
      password: 'secret', 
      confirmation: 'verification' 
    })

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Defines the root path route ("/")
  # root "posts#index"

  resources :labels, only: [:index]
  resources :threads
  namespace :gm do
    resources :message_actions, only: [:index]
  end

  root 'home#index'
  
  # get '/auth/google_oauth/callback', to: 'sessions#create'
  # get '/auth/failure', to: redirect('/')
  # delete '/signout', to: 'sessions#destroy', as: 'signout'
  
  resources :emails, only: [:index]
end