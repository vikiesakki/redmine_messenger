raise "\n\033[31mredmine_messenger requires ruby 2.3 or newer. Please update your ruby version.\033[0m" if RUBY_VERSION < '2.3'
$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/lib/"
require 'redmine'
require 'redmine_messenger/patches/contact_patch'
require 'redmine_messenger/patches/db_entry_patch'
require 'redmine_messenger/patches/issue_patch'
require 'redmine_messenger/patches/password_patch'
require 'redmine_messenger/patches/projects_helper_patch'
require 'redmine_messenger/patches/wiki_page_patch'
require 'redmine_messenger/helpers'
require 'redmine_messenger/hooks'
Rails.configuration.to_prepare do
  REDMINE_CONTACTS_SUPPORT = Redmine::Plugin.installed?('redmine_contacts') ? true : false
  REDMINE_DB_SUPPORT = Redmine::Plugin.installed?('redmine_db') ? true : false
  # this does not work at the moment, because redmine loads passwords after messener plugin
  REDMINE_PASSWORDS_SUPPORT = Redmine::Plugin.installed?('redmine_passwords') ? true : false

    @@zoho_token=""

    def self.zoho_token
      @@zoho_token
    end
    
    def self.zoho_token=zoho_token
      @@zoho_token = zoho_token
    end

    def self.settings
      if Setting[:plugin_redmine_messenger].class == Hash
        if Rails.version >= '5.2'
          # convert Rails 4 data
          new_settings = ActiveSupport::HashWithIndifferentAccess.new(Setting[:plugin_redmine_messenger])
          Setting.plugin_redmine_messenger = new_settings
          new_settings
        else
          ActionController::Parameters.new(Setting[:plugin_redmine_messenger])
        end
      else
        # Rails 5 uses ActiveSupport::HashWithIndifferentAccess
        Setting[:plugin_redmine_messenger]
      end
    end

    def self.setting?(value)
      return true if settings[value].to_i == 1
      false
    end

    def self.logintoZoho
      zoho_username = settings['zoho_username']
      zoho_userpwd = settings['zoho_userpwd']
      zoho_channel = settings['zoho_channel']
      
      params = {
          SCOPE:        'ZohoCliq/InternalAPI',
          EMAIL_ID:     zoho_username,
          PASSWORD:     zoho_userpwd,
          display_name: 'ZOHOCLIQ'
      }

      uri = URI.parse('https://accounts.zoho.com/apiauthtoken/nb/create')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path, {'Content-Type' => 'text/json'})
      request.set_form_data(params)

      # send the request
      response = http.request(request)
      res_body = response.body.split("\n")
      self.zoho_token = res_body[2].split('=')[1]
      Rails.logger.warn(response) unless [Net::HTTPSuccess, Net::HTTPRedirection, Net::HTTPOK].include? response
    end

  # Patches
  Issue.send(:include, RedmineMessenger::Patches::IssuePatch)
  WikiPage.send(:include, RedmineMessenger::Patches::WikiPagePatch)
  ProjectsHelper.send :include, MessengerProjectsHelper
  Contact.send(:include, RedmineMessenger::Patches::ContactPatch) if RedmineMessenger::REDMINE_CONTACTS_SUPPORT
  DbEntry.send(:include, RedmineMessenger::Patches::DbEntryPatch) if RedmineMessenger::REDMINE_DB_SUPPORT
  Password.send(:include, RedmineMessenger::Patches::PasswordPatch) if Redmine::Plugin.installed?('redmine_passwords')

  # Global helpers
  

  # Hooks
  require_dependency 'redmine_messenger/hooks'
end

Redmine::Plugin.register :redmine_messenger do
  name 'Redmine Messenger'
  author 'Andres'
  url ''
  author_url ''
  description 'Messenger integration for Slack, Discord, Rocketchat, Mattermost and Zoho support'
  version '1.0.5'

  requires_redmine version_or_higher: '3.0.0'

  permission :manage_messenger, projects: :settings, messenger_settings: :update

  settings default: {
    messenger_url: '',
    messenger_icon: 'https://raw.githubusercontent.com/alphanodes/redmine_messenger/master/assets/images/icon.png',
    messenger_channel: 'redmine',
    messenger_username: 'robot',
    messenger_verify_ssl: '1',
    zoho_authtoken: '',
    zoho_channel:'',
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
