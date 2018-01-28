# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

resources :projects do
  resource :messenger_setting, only: %i[show update]
end
