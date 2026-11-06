Rails.application.routes.draw do
  mount Uchujin::Engine => "/uchujin"
  resource :session
  resources :passwords, param: :token
  resource :registration, only: %i[new create]

  resources :exercises, only: %i[index show]
  resources :workouts do
    get :play, on: :member
  end
  resources :workout_logs, path: "history", only: %i[index show create update destroy]
  resources :routine_items, path: "routine", only: %i[index create destroy] do
    patch :move, on: :member # params[:direction] = "up" | "down"
  end
  resource :settings, only: %i[show update]
  resource :stats, only: :show
  resources :push_subscriptions, only: %i[create] do
    post :test, on: :collection
  end
  delete "push_subscriptions" => "push_subscriptions#destroy" # by params[:endpoint]
  get "science" => "pages#science"

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "up" => "rails/health#show", as: :rails_health_check

  get "dev/login" => "dev#login" if Rails.env.development?

  root "home#show"
end
