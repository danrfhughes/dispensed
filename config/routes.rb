Rails.application.routes.draw do
  get "adherence/index"
  devise_for :users

  authenticate :user do
    resources :medications do
      resources :schedules, only: [:new, :create, :edit, :update, :destroy]
    end
    resources :doses, only: [] do
      member do
        patch :take
        patch :skip
      end
    end
    get "dashboard", to: "dashboard#index", as: :dashboard
    root "dashboard#index"
    get "adherence", to: "adherence#index", as: :adherence
    resource :pharmacy, only: [:show, :new, :create, :edit, :update]
  end
end