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

      patch 'archive'
      patch 'activate'
    end

    resources :batches, except: [:index, :new, :show] do
      member do
        get 'download'

        post 'generate'
      end
    end

    resources :on_site_attendees, except: [:show], path: 'on-site' do
      collection do
        get 'crm-contact'
        get 'crm-account'
      end

      member do
        get 'print'
      end
    end
  end
end
