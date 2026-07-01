Rails.application.routes.draw do
  devise_for :users

  get "up" => "rails/health#show", as: :rails_health_check

  resources :properties do
    resources :rental_agreements, only: [:new, :create, :edit, :update, :destroy]
  end

  root "properties#index"
end
