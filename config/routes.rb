require 'sidekiq/web'

Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  mount Sidekiq::Web => '/sidekiq'

  namespace :api do
    namespace :v1 do
      resources :job_requests, only: [:create, :show] do
        member do
          post :cancel
        end
      end
    end
  end

  # Defines the root path route ("/")
  # root "articles#index"
end
