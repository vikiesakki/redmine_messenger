module RedmineMessenger
  module Patches
    module WikiPagePatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          after_create :send_messenger_create
          after_update :send_messenger_update
        end
      end

      module InstanceMethods
        def send_messenger_create
          return unless Messenger.setting_for_project(project, :post_wiki)

          set_language_if_valid Setting.default_language

          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project

          return unless channels.present? && url

          Messenger.speak(l(:label_messenger_wiki_created,
                            project_url: "<#{Messenger.object_url project}|#{ERB::Util.html_escape(project)}>",
                            url: "<#{Messenger.object_url self}|#{title}>",
                            user: User.current),
                          channels, url, project: project)

          Messenger.speak_zoho(l(:label_messenger_wiki_zoho_created,
                            project_url: "[#{ERB::Util.html_escape(project)}](#{Messenger.object_url project})",
                            url: "[#{title}](#{Messenger.object_url self})",
                            user: User.current),
                          Messenger.zoho_message_url(project), project: project)
        end

        def send_messenger_update
          return unless Messenger.setting_for_project(project, :post_wiki_updates)

          set_language_if_valid Setting.default_language

          channels = Messenger.channels_for_project project
          url = Messenger.url_for_project project

          return unless channels.present? && url

          attachment = nil
          if !content.nil? && content.comments.present?
            attachment = {}
            attachment[:text] = Messenger.markup_format(content.comments.to_s)
          end

          Messenger.speak(l(:label_messenger_wiki_updated,
                            project_url: "<#{Messenger.object_url project}|#{ERB::Util.html_escape(project)}>",
                            url: "<#{Messenger.object_url self}|#{title}>",
                            user: content.author),
                          channels, url, project: project, attachment: attachment)
          Messenger.speak_zoho(l(:label_messenger_wiki_zoho_updated,
                            project_url: "[#{ERB::Util.html_escape(project)}](#{Messenger.object_url project})",
                            url: "[#{title}](#{Messenger.object_url self})",
                            user: content.author),
                           Messenger.zoho_message_url(project), project: project, attachment: attachment)
        end
      end
    end
  end
end
