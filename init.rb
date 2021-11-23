# frozen_string_literal: true

raise "\n\033[31mredmine_messenger requires ruby 2.6 or newer. Please update your ruby version.\033[0m" if RUBY_VERSION < '2.6'

Redmine::Plugin.register :redmine_messenger do
  name 'Redmine Messenger'
  author 'AlphaNodes GmbH'
  url 'https://github.com/alphanodes/redmine_messenger'
  author_url 'https://alphanodes.com/'
  description 'Messenger integration for Slack, Discord, Rocketchat and Mattermost support'
  version RedmineMessenger::VERSION

  requires_redmine version_or_higher: '4.1.0'

  permission :manage_messenger, projects: :settings, messenger_settings: :update

  settings default: {
    messenger_url: '',
    messenger_icon: 'https://raw.githubusercontent.com/alphanodes/redmine_messenger/master/assets/images/icon.png',
    messenger_channel: 'redmine',
    messenger_username: 'robot',
    messenger_verify_ssl: '1',
    messenger_direct_users_messages: '0',
    auto_mentions: '0',
    default_mentions: '',
    display_watchers: '0',
    post_updates: '1',
    new_include_description: '1',
    updated_include_description: '1',
    post_private_contacts: '0',
    post_private_db: '0',
    post_private_issues: '0',
    post_private_notes: '0',
    post_wiki: '0',
    post_wiki_updates: '0',
    post_db: '0',
    post_db_updates: '0',
    post_contact: '0',
    post_contact_updates: '0',
    post_password: '0',
    post_password_updates: '0'
  }, partial: 'settings/messenger_settings'
end

if Rails.version > '6.0'
  ActiveSupport.on_load(:active_record) { RedmineMessenger.setup }
else
  Rails.configuration.to_prepare { RedmineMessenger.setup }
end
