Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  root "dashboard#show"

  resource :dashboard, only: :show, controller: "dashboard"

  resources :agents do
    member do
      patch :update_status
    end
  end

  resources :queue_configs, path: "queues" do
    resources :queue_memberships, path: "members", only: %i[create destroy]
  end

  resources :route_rules, path: "routes"

  resources :call_records, path: "calls", only: %i[index show]

  resources :recordings, only: %i[index show] do
    member do
      get :stream
      get :download
    end
  end

  resources :users, only: %i[index new create edit update destroy]

  get "web_phone/credentials", to: "web_phone#credentials"

  get "up" => "rails/health#show", as: :rails_health_check
end
