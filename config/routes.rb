
Rails.application.routes.draw do
  root 'qr_codes#index'

  get '/login',           to: 'sessions#new'
  post '/login',          to: 'sessions#create'
  delete '/logout',       to: 'sessions#destroy'

  resources :locations,   except: [:show]
  resources :event_types, except: [:show], path: 'event-types'

  get 'event',						to: 'qr_codes#show'
  get 'archives',					to: 'qr_codes#show_archives'
  get 'edit',							to: 'qr_codes#edit'
  get 'download',					to: 'qr_codes#download'

  post 'update',					to: 'qr_codes#update'
  post 'upload',					to: 'qr_codes#upload'
  post 'upload-batch',		to: 'qr_codes#upload_batch'
  post 'archive',					to: 'qr_codes#archive'
  post 'activate',				to: 'qr_codes#activate'
  post 'generate',				to: 'qr_codes#generate'

  delete 'destroy',       to: 'qr_codes#destroy'
  delete 'destroy-batch', to: 'qr_codes#destroy_batch'
end
