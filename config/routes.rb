Rails.application.routes.draw do
  devise_for :users

  admin_constraint = lambda { |request| request.env["warden"].authenticate(scope: :user)&.admin? }

  constraints admin_constraint do
    namespace :backoffice do
      resources :expenses
      resources :landlords
      resources :payments
      resources :properties
      resources :rental_agreements
      resources :users

      root to: "expenses#index"
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
  post "set_locale" => "locales#set", as: :set_locale

  resources :properties do
    member do
      get :tax_report
    end
    resources :expenses, only: [:create, :edit, :update, :destroy]
    resources :rental_agreements, only: [:new, :create, :show, :edit, :update, :destroy] do
      resources :payments, only: [:edit, :update, :destroy] do
        collection do
          post :create_recurring
        end
      end
    end
  end

  root "properties#index"
end
