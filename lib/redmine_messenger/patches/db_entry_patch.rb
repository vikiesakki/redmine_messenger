module RedmineMessenger
  module Patches
    module DbEntryPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          after_create :send_messenger_create
          after_update :send_messenger_update
        end
      end

      module InstanceMethods
        def send_messenger_create
          return unless Messenger.setting_for_project(project, :post_db)
          return if is_private? && !Messenger.setting_for_project(project, :post_private_db)

          set_language_if_valid Setting.default_language

          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project

          return unless channels.present? && url

          Messenger.speak(l(:label_messenger_db_entry_created,
                            project_url: "<#{Messenger.object_url project}|#{ERB::Util.html_escape(project)}>",
                            url: "<#{Messenger.object_url self}|#{name}>",
                            user: User.current),
                          channels, url, project: project)

          Messenger.speak_zoho(l(:label_messenger_db_entry_zoho_created,
                            project_url: "[#{ERB::Util.html_escape(project)}](#{Messenger.object_url project})",
                            url: "[#{name}](#{Messenger.object_url self})",
                            user: User.current),
                          channels, url, project: project)
        end

        def send_messenger_update
          return unless Messenger.setting_for_project(project, :post_db_updates)
          return if is_private? && !Messenger.setting_for_project(project, :post_private_db)

          set_language_if_valid Setting.default_language

          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project

          return unless channels.present? && url

          Messenger.speak(l(:label_messenger_db_entry_updated,
                            project_url: "<#{Messenger.object_url project}|#{ERB::Util.html_escape(project)}>",
                            url: "<#{Messenger.object_url self}|#{name}>",
                            user: User.current),
                          channels, url, project: project)

          Messenger.speak(l(:label_messenger_db_entry_zoho_updated,
                            project_url: "[#{ERB::Util.html_escape(project)}](#{Messenger.object_url project})",
                            url: "[#{name}](#{Messenger.object_url self})",
                            user: User.current),
                          channels, url, project: project)
        end
      end
    end
  end
end
DbEntry.send(:include, RedmineMessenger::Patches::DbEntryPatch) if RedmineMessenger::REDMINE_DB_SUPPORT
