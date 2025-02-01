module RedmineMessenger
  module Patches
    module ContactPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          after_create :send_messenger_create
          after_update :send_messenger_update
        end
      end

      module InstanceMethods
        def send_messenger_create
          return unless Messenger.setting_for_project(project, :post_contact)
          return if is_private? && !Messenger.setting_for_project(project, :post_private_contacts)
          setting = MessengerSetting.where(project_id: project.id).first
          return if setting.disable_chat

          set_language_if_valid Setting.default_language

          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project

          teams_channel = Messenger.teams_channel(project)
          if teams_channel.present?
            MessengerTeamsJob.perform_later(Messenger.new.teams_common_message(self, 'created', User.current), teams_channel)
          end

          return unless channels.present? && url

          Messenger.speak(l(:label_messenger_contact_created,
                            project_url: "<#{Messenger.object_url project}|#{ERB::Util.html_escape(project)}>",
                            url: "<#{Messenger.object_url self}|#{name}>",
                            user: User.current),
                          channels, url, project: project)

          Messenger.speak_zoho(l(:label_messenger_contact_created,
                            project_url: "[#{ERB::Util.html_escape(project)}](#{Messenger.object_url project})",
                            url: "[#{name}](#{Messenger.object_url self})",
                            user: User.current),
                          channels, url, project: project)
        end

        def send_messenger_update
          return unless Messenger.setting_for_project(project, :post_contact_updates)
          return if is_private? && !Messenger.setting_for_project(project, :post_private_contacts)
          setting = MessengerSetting.where(project_id: project.id).first
          return if setting.disable_chat
          
          set_language_if_valid Setting.default_language

          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project
          teams_channel = Messenger.teams_channel(project)
          if teams_channel.present?
            MessengerTeamsJob.perform_later(Messenger.new.teams_common_message(self, 'updated', User.current), teams_channel)
          end
          
          return unless channels.present? && url

          Messenger.speak(l(:label_messenger_contact_updated,
                            project_url: "<#{Messenger.object_url project}|#{ERB::Util.html_escape(project)}>",
                            url: "<#{Messenger.object_url self}|#{name}>",
                            user: User.current),
                          channels, url, project: project)
          
          Messenger.speak_zoho(l(:label_messenger_contact_zoho_updated,
                            project_url: "[#{ERB::Util.html_escape(project)}](#{Messenger.object_url project})",
                            url: "[#{name}](#{Messenger.object_url self})",
                            user: User.current),
                          channels, url, project: project)
        end
      end
    end
  end
end
Contact.send(:include, RedmineMessenger::Patches::ContactPatch) if RedmineMessenger::REDMINE_CONTACTS_SUPPORT
