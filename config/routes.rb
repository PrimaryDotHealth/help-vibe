Rails.application.routes.draw do
  # Staff sign-in (Rails 8 authentication generator)
  resource :session
  resources :passwords, param: :token

  # Help center (reader side): S01, S02, S03, S04
  root "reader/home#show"
  scope module: :reader do
    get "c/:slug", to: "chapters#show", as: :chapter
    get "a/:slug", to: "articles#show", as: :article
    get "search", to: "search#index", as: :search
  end

  # Admin: articles (S11), editor (S12), chapters (S15)
  namespace :admin do
    root "articles#index"
    resources :articles, only: %i[index new create edit update] do
      resource :publication, only: %i[create destroy]
    end
    resources :versions, only: [] do
      resources :revisions, only: :create
    end
    resources :chapters, except: %i[show destroy]
  end

  # Embeddable help widget (S07)
  get "embed.js", to: "widget/embed#show", as: :embed_script, defaults: { format: :js }
  namespace :widget do
    root "panel#show"
    get "search", to: "panel#search"
    get "a/:slug", to: "panel#article", as: :article
  end

  # A stand-in for our product, to try the widget locally
  get "dev/host", to: "dev#host" if Rails.env.development?

  get "up" => "rails/health#show", as: :rails_health_check
end
