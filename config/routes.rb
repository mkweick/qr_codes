Rails.application.routes.draw do
  root 'qr_codes#index'

  get 'spreadsheet'    => 'qr_codes#show'
  post 'upload-spreadsheet' => 'qr_codes#upload'
end
