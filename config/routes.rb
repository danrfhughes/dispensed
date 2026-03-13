Rails.application.routes.draw do
  get "adherence/index"
  devise_for :users, controllers: { omniauth_callbacks: "users/omniauth_callbacks" }

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
    # Pharmacy routes removed — replaced by Organisation model (NHS-2)
  end
end