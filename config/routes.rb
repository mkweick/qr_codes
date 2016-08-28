
Rails.application.routes.draw do
  root 'qr_codes#index'

  resources :locations,   except: [:show]
  resources :event_types, except: [:show], path: 'event-types'

  get 'event'							=> 'qr_codes#show'
  get 'archives'					=> 'qr_codes#show_archives'
  get 'edit'							=> 'qr_codes#edit'
  get 'download'					=> 'qr_codes#download'

  post 'update'						=> 'qr_codes#update'
  post 'upload'						=> 'qr_codes#upload'
  post 'upload-batch'			=> 'qr_codes#upload_batch'
  post 'archive'					=> 'qr_codes#archive'
  post 'activate'					=> 'qr_codes#activate'
  post 'generate'					=> 'qr_codes#generate'

  delete 'destroy'				=> 'qr_codes#destroy'
  delete 'destroy-batch'	=> 'qr_codes#destroy_batch'
end
