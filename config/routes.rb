Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"

  namespace :api do
    namespace :v1 do
      post "users/create", to: "/users/api/v1/users#create"
      post "users/login", to: "/users/api/v1/users#login"
      get "users/me", to: "/users/api/v1/users#me"
      get "users/counterparties", to: "/users/api/v1/users#counterparties"
      patch "users/me", to: "/users/api/v1/users#update_me"
      resources :accounts, controller: "/accounts/api/v1/accounts", param: :code, only: [ :index, :create, :update, :destroy ]
      post "transactions/import/preview", to: "/transactions/api/v1/transactions#import_preview"
      post "transactions/import/commit", to: "/transactions/api/v1/transactions#import_commit"
      get "transactions", to: "/transactions/api/v1/transactions#index"
      patch "transactions/bulk", to: "/transactions/api/v1/transactions#bulk_update"
      delete "transactions/bulk", to: "/transactions/api/v1/transactions#bulk_delete"
      post "transactions/bulk/move", to: "/transactions/api/v1/transactions#bulk_move"
      post "transactions/bulk/export_csv", to: "/transactions/api/v1/transactions#bulk_export_csv"
      post "transactions/bulk/generate_report", to: "/transactions/api/v1/transactions#bulk_generate_report"
      get "transactions/stats", to: "/transactions/api/v1/transactions#stats"
      post "transactions", to: "/transactions/api/v1/transactions#create"
      patch "transactions/:code", to: "/transactions/api/v1/transactions#update"
      get "statistics", to: "/transactions/api/v1/statistics#show"
    end
  end

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check
end
