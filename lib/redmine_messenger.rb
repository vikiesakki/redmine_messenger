# frozen_string_literal: true

require 'redmine_messenger/version'

module RedmineMessenger
  REDMINE_CONTACTS_SUPPORT = Redmine::Plugin.installed? 'redmine_contacts'
  REDMINE_DB_SUPPORT = Redmine::Plugin.installed? 'redmine_db'

  class << self
    def setup
      # Patches
      Issue.include RedmineMessenger::Patches::IssuePatch
      Project.include RedmineMessenger::Patches::ProjectPatch
      WikiPage.include RedmineMessenger::Patches::WikiPagePatch
      ProjectsController.send :helper, MessengerProjectsHelper
      Contact.include RedmineMessenger::Patches::ContactPatch if RedmineMessenger::REDMINE_CONTACTS_SUPPORT
      DbEntry.include RedmineMessenger::Patches::DbEntryPatch if RedmineMessenger::REDMINE_DB_SUPPORT
      Password.include RedmineMessenger::Patches::PasswordPatch if Redmine::Plugin.installed? 'redmine_passwords'

      # Global helpers
      ActionView::Base.include RedmineMessenger::Helpers

      # Hooks
      require_dependency 'redmine_messenger/hooks'
    end

    def settings
      if Setting[:plugin_redmine_messenger].is_a? Hash
        new_settings = ActiveSupport::HashWithIndifferentAccess.new Setting[:plugin_redmine_messenger]
        Setting.plugin_redmine_messenger = new_settings
        new_settings
      else
        # Rails 5 uses ActiveSupport::HashWithIndifferentAccess
        Setting[:plugin_redmine_messenger]
      end
    end

    def setting?(value)
      return true if settings[value].to_i == 1

      false
    end
  end
end
