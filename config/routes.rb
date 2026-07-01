Rails.application.routes.draw do
  devise_for :users

  get "up" => "rails/health#show", as: :rails_health_check

  resources :properties do
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
