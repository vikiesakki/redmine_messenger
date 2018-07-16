module RedmineMessenger
  module Patches
    module ProjectsHelperPatch
      def self.included(base)
        base.send(:include, InstanceMethods)
        base.class_eval do
          alias_method :project_settings_tabs_without_additionals, :project_settings_tabs
          alias_method :project_settings_tabs, :project_settings_tabs_with_additionals
        end
      end

      module InstanceMethods
        def project_settings_tabs_with_messenger
          tabs = project_settings_tabs_without_messenger
          action = { name: 'messenger',
                     action: :show,
                     partial: 'messenger_settings/show',
                     label: :label_messenger }

          tabs << action if User.current.allowed_to?(:manage_messenger, @project)
          tabs
        end
      end
    end
  end
end

unless ProjectsHelper.included_modules.include?(RedmineMessenger::Patches::ProjectsHelperPatch)
  ProjectsHelper.send(:include, RedmineMessenger::Patches::ProjectsHelperPatch)
end
