Rails.application.routes.draw do
  # Staff sign-in (Rails 8 authentication generator) and invitations
  resource :session
  resources :passwords, param: :token
  resources :invitations, only: %i[show update], param: :token

  # Help center (reader side): S01, S02, S03, S04
  root "reader/home#show"
  scope module: :reader do
    get "c/:slug", to: "chapters#show", as: :chapter
    get "a/:slug", to: "articles#show", as: :article
    get "a/:slug/v/:number", to: "articles#show", as: :article_version
    post "a/:slug/vote", to: "votes#create", as: :article_vote
    get "search", to: "search#index", as: :search
  end

  # Admin: articles (S11), editor (S12), history (S13), chapters (S15),
  # people (S17), API keys (S20), import (S22)
  namespace :admin do
    root "articles#index"
    resources :articles, only: %i[index new create edit update] do
      resource :publication, only: %i[create destroy]
      resource :history, only: :show, controller: "history" do
        post :restore
      end
    end
    resources :versions, only: [] do
      resources :revisions, only: :create
      resources :reviews, only: :create
      resources :comments, only: :create
      resource :markdown, only: :create
    end
    resources :reviews, only: :destroy do
      post :decide, on: :member
    end
    resources :comments, only: :update
    resources :chapters, except: %i[show destroy]
    resources :users, except: %i[show destroy]
    resources :groups, except: :show
    resources :api_keys, only: %i[index create destroy]
    resource :import, only: %i[show create], controller: "import"
    resources :context_rules, except: :show
    resource :analytics, only: :show
    resources :webhooks, except: :edit do
      member { post :toggle; post :test }
    end
    resources :activities, only: :index
    resource :settings, only: %i[show update]
  end

  # Embeddable help widget (S07) and chromeless article for iframes (S08)
  get "embed.js", to: "widget/embed#show", as: :embed_script, defaults: { format: :js }
  get "embed/a/:slug", to: "widget/panel#embed", as: :embedded_article
  namespace :widget do
    root "panel#show"
    get "search", to: "panel#search"
    get "a/:slug", to: "panel#article", as: :article
    resource :session, only: %i[create destroy]
  end

  # Helpjuice-shaped read API
  namespace :api, defaults: { format: :json } do
    namespace :v3 do
      get "search", to: "search#index"
      resources :articles, only: %i[index show create update destroy]
      resources :categories, only: %i[index show create update]
    end
  end

  # A stand-in for our product, to try the widget locally
  get "dev/host", to: "dev#host" if Rails.env.local?

  get "up" => "rails/health#show", as: :rails_health_check

  # Last: Helpjuice links keep working: /en_US/<category>/<codename> and /<codename>
  get "en_US/*path", to: "reader/redirects#show", format: false
  get "*path", to: "reader/redirects#show", format: false,
      constraints: ->(req) { !req.path.start_with?("/rails/", "/assets/", "/admin", "/api/", "/widget") }
end
