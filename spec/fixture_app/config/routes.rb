Rails.application.routes.draw do
  devise_for :users, skip: [:registrations, :passwords]

  # Studiz: route_translator with Danish segments; `da` unprefixed, `/en/...` prefixed.
  localized do
    root "home#index"
    get "preview", to: "home#preview"
    get "preview_frame", to: "home#preview_frame"
    get "terms", to: "home#terms"
    get "double_render", to: "home#double_render"

    resources :institutions, only: [] do
      resources :students, only: [:index], controller: "institutions/students"
      resources :events, controller: "institutions/events", except: [:show]
    end
    resources :events, only: [:show]

    resources :providers, only: [] do
      namespace :admin, module: "providers/admin" do
        resources :discounts do
          member do
            post :send_reminder
            get :archive
            post :confirm_archive
          end
        end
      end
    end

    resource :student_organisation, only: [] do
      resources :student_organisation_memberships, controller: "student_organisations/memberships", only: [:index, :new, :create, :destroy]
    end

    resources :user_messages, only: [:index, :create]
    resources :invoices, only: [:show]
    resource :profile, only: [:edit, :update]
  end

  # Outside the localised scope, like Studiz's /backoffice, /live_support, /api.
  namespace :backoffice do
    resources :leads, only: [:index, :edit, :update]
  end

  get "js-test-page", to: "home#js_test_page"

  namespace :live_support do
    get :ping, to: "pings#ping"
    post :ping, to: "pings#ping_post"
  end
end
