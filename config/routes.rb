
Rails.application.routes.draw do
  root 'events#index'

  get '/login',     to: 'sessions#new'
  post '/login',    to: 'sessions#create'
  delete '/logout', to: 'sessions#destroy'

  resources :events, except: [] do
    resources :batches, except: []
  end

  resources :locations, except: [:show]
  resources :types,     except: [:show]

  get 'archives',					  to: 'qr_codes#archives'
  get 'edit',							  to: 'qr_codes#edit'
  get 'download',					  to: 'qr_codes#download'

  get 'on-site-badge',      to: 'qr_codes#on_site_badge'
  get 'crm-contact',        to: 'qr_codes#crm_contact'
  get 'on-demand',          to: 'qr_codes#on_demand'
  get 'generate-crm',       to: 'qr_codes#generate_crm'

  post 'update',					  to: 'qr_codes#update'
  post 'upload',				  	to: 'qr_codes#upload'
  post 'upload-batch',		  to: 'qr_codes#upload_batch'
  post 'archive-event',			to: 'qr_codes#archive_event'
  post 'activate',				  to: 'qr_codes#activate'
  post 'generate',				  to: 'qr_codes#generate'

  delete 'destroy',         to: 'qr_codes#destroy'
  delete 'destroy-batch',   to: 'qr_codes#destroy_batch'
end
