Rails.application.routes.draw do
  root 'events#index'

  get '/login',     to: 'sessions#new'
  post '/login',    to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'

  resources :locations, except: [:show]
  resources :types,     except: [:show]

  resources :events, except: [:new] do
    collection do
      get 'archives'
    end

    member do 
      get 'download-template'
      get 'on-site-badge'
      get 'crm-contact'
      get 'on-demand'
      get 'generate-crm'

      patch 'archive'
      patch 'activate'
    end

    resources :batches, except: [:index, :new, :show] do
      member do
        get 'download'

        post 'generate'
      end
    end
  end
end
