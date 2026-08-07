Rails.application.routes.draw do
  namespace :two_factor_authentication do
    resource :setup, only: [ :show, :update ], controller: "setup"
    resource :session, only: [ :show, :create ], controller: "sessions"
  end

  devise_for :users, controllers: {
    sessions: "users/sessions",
  }

  resource :settings, only: [ :show, :update ] do
    scope module: :settings do
      resource :sorting, only: [ :show, :update ], controller: "sorting" do
        resources :custom_sorts, only: [ :new, :create, :edit, :update, :destroy ]
      end
      resources :labels, except: [ :show, :new ] do
        member { get :confirm_delete }
      end
      resource :visibility, only: [ :show, :update ], controller: "visibility" do
        resources :profile_accesses, only: [ :create, :destroy ]
        resources :share_links, only: [ :create, :destroy ]
      end
    end
  end

  # Every collectible path is nested under its owner's profile, so the URL
  # always shows whose collection it belongs to.
  scope "u/:username", as: :profile do
    resource :follow, only: [ :create, :destroy ]
    resources :collectibles, except: [ :index ] do
      member do
        get :confirm_delete
      end
      collection do
        get :import
        get :import_template
        post :import_review
        post :import_create
      end
    end
  end

  # Public/shared collection view for a given user.
  get "u/:username", to: "profiles#show", as: :profile

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  # Every collection the viewer can see, with search and filtering.
  resources :collections, only: [ :index ]

  # Defines the root path route ("/")
  root "root#index"
end
