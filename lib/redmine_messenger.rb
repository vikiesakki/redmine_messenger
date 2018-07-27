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
  Issue.send(:include, RedmineMessenger::Patches::IssuePatch)
  WikiPage.send(:include, RedmineMessenger::Patches::WikiPagePatch)
  ProjectsController.send :helper, MessengerProjectsHelper
  Contact.send(:include, RedmineMessenger::Patches::ContactPatch) if RedmineMessenger::REDMINE_CONTACTS_SUPPORT
  DbEntry.send(:include, RedmineMessenger::Patches::DbEntryPatch) if RedmineMessenger::REDMINE_DB_SUPPORT
  Password.send(:include, RedmineMessenger::Patches::PasswordPatch) if Redmine::Plugin.installed?('redmine_passwords')

  # Global helpers
  ActionView::Base.send :include, RedmineMessenger::Helpers

  # Hooks
  require_dependency 'redmine_messenger/hooks'
end
