# frozen_string_literal: true

Rails.application.routes.draw do
  resources :projects, only: [] do
    resource :messenger_setting, only: %i[show update]
  end
end
