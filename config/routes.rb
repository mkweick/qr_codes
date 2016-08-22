Rails.application.routes.draw do
  root 'qr_codes#index'

  get 'event'							=> 'qr_codes#show'
  get 'archives'					=> 'qr_codes#show_archives'

  post 'upload'						=> 'qr_codes#upload'
  post 'archive'					=> 'qr_codes#archive'
  post 'activate'					=> 'qr_codes#activate'

  delete 'destroy'				=> 'qr_codes#destroy'
end
