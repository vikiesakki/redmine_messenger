# Redmine Messenger plugin for Redmine

Rails.configuration.to_prepare do
  module RedmineMessenger
    REDMINE_CONTACTS_SUPPORT = Redmine::Plugin.installed?('redmine_contacts') ? true : false
    REDMINE_DB_SUPPORT = Redmine::Plugin.installed?('redmine_db') ? true : false
    # this does not work at the moment, because redmine loads passwords after messener plugin
    REDMINE_PASSWORDS_SUPPORT = Redmine::Plugin.installed?('redmine_passwords') ? true : false

    def self.settings
      ActionController::Parameters.new(Setting[:plugin_redmine_messenger])
    end

    def self.setting?(value)
      return true if settings[value].to_i == 1
      false
    end
  end

  # Patches
  require_dependency 'redmine_messenger/patches/issue_patch'
  require_dependency 'redmine_messenger/patches/wiki_page_patch'
  require_dependency 'redmine_messenger/patches/projects_helper_patch'

  require 'redmine_messenger/patches/contact_patch' if RedmineMessenger::REDMINE_CONTACTS_SUPPORT
  require 'redmine_messenger/patches/db_entry_patch' if RedmineMessenger::REDMINE_DB_SUPPORT
  require 'redmine_messenger/patches/password_patch' if Redmine::Plugin.installed?('redmine_passwords')

  # Global helpers
  require_dependency 'redmine_messenger/helpers'

  # Hooks
  require_dependency 'redmine_messenger/hooks'
end
