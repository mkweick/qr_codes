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

# ------------------------------------------------------

  get 'download',					  to: 'qr_codes#download'
  get 'on-site-badge',      to: 'qr_codes#on_site_badge'
  get 'crm-contact',        to: 'qr_codes#crm_contact'
  get 'on-demand',          to: 'qr_codes#on_demand'
  get 'generate-crm',       to: 'qr_codes#generate_crm'

  post 'generate',				  to: 'qr_codes#generate'
end
