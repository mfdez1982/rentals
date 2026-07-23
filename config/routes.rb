Rails.application.routes.draw do
  devise_for :users, controllers: { registrations: "users/registrations" }

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

  resources :notes, only: [:index, :create, :edit, :update, :destroy] do
    member do
      patch :mark_complete
    end
  end

  resources :my_rentals, only: [:index, :show]

  resources :properties do
    resources :tax_reports, only: [:index, :create, :show, :destroy]
    resources :expenses, only: [:create, :edit, :update, :destroy] do
      resources :recollections, only: [:new, :create]
    end
    resources :recollections, only: [:destroy] do
      member do
        patch :mark_paid
        patch :mark_unpaid
      end
    end
    resources :rental_agreements, only: [:new, :create, :show, :edit, :update, :destroy] do
      resources :payments, only: [:edit, :update, :destroy] do
        collection do
          post :create_recurring
        end
      end
      resources :agreement_tenants, only: [:create, :destroy] do
        member do
          post :retry
          post :acknowledge
        end
      end
    end
  end

  resources :tenant_invitations, only: [] do
    member do
      post :accept
      post :reject
      post :dismiss
    end
  end

  get "landing", to: "pages#landing"

  root "properties#index"
end
