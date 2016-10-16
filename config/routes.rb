Rails.application.routes.draw do
  root 'events#index'

  get '/login',     to: 'sessions#new'
  post '/login',    to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'

  resources :locations,     except: [:show]
  resources :types,         except: [:show]

  resources :dival_badges,  only: [:new] do
    collection do
      get 'print'
      get 'crm-dival-employee'
    end
  end

  resources :vendor_badges,  only: [:new] do
    collection do
      get 'print'
    end
  end

  resources :events, except: [:new] do
    collection do
      get 'archives'
    end

    member do 
      get 'download-attendee-template'
      get 'download-employee-template'

      patch 'archive'
      patch 'activate'
    end

    resources :crm_campaigns, path: 'crm-campaigns', only: [:create, :destroy] do
      collection do
        get 'search'
      end
    end

    resources :check_ins, path: 'check-in', only: [:new] do
      collection do
        get 'search'
        
        patch 'attended'
        patch 'not-attended'
      end
    end

    resources :batches, except: [:index, :new, :show] do
      member do
        get 'download'

        post 'generate'
      end
    end

    resources :on_site_attendees, path: 'on-site' do
      collection do
        get 'crm-contact'
        get 'as400-account'
        get 'as400-ship-to'
        get 'download'
      end
    end
  end
end
