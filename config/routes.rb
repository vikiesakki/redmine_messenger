# Plugin's routes
# See: http://guides.rubyonrails.org/routing.html

# Don't create routes for repositories resources with only: []
# do not override Redmine's routes.
match 'NotifyChannel', to: 'messenger_settings#notify_all', via: [:get, :post]
match 'NotifyUptime', to: 'messenger_settings#uptime_notification', via: [:get, :post]
match 'create/chat/:project_id',as: 'create_chat', to: 'messenger_settings#create_chat', via: [:get, :post]
resources :projects, only: [] do
  resource :messenger_setting, only: %i[show update]
end
