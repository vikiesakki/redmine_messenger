module RedmineMessenger
    module Patches
        module ProjectsHelperPatch
            def self.included(base)
                base.send(:include, InstanceMethods)

                base.class_eval do
                    unloadable
                    alias_method :project_settings_tabs_without_messanger, :project_settings_tabs
                    alias_method :project_settings_tabs, :project_settings_tabs_with_messanger
                end
            end
            module InstanceMethods
                def project_settings_tabs_with_messanger
                    tabs = project_settings_tabs_without_messanger
                    tab = {:name => 'messenger',
                    :action => 'show',
                    :label => :label_messenger,
                    :partial => 'messenger_settings/show'
                    }
                    tabs << tab if User.current.allowed_to?(:manage_messenger, @project)
                    tabs
                end
                def project_messenger_options(active)
                  options_for_select({ l(:label_messenger_settings_default) => '0',
                                       l(:label_messenger_settings_disabled) => '1',
                                       l(:label_messenger_settings_enabled) => '2' }, active)
                end

                def project_setting_messenger_default_value(value)
                  if Messenger.default_project_setting(@project, value)
                    l(:label_messenger_settings_enabled)
                  else
                    l(:label_messenger_settings_disabled)
                  end
                end
            end
        end
    end
end
unless ProjectsHelper.included_modules.include?(RedmineMessenger::Patches::ProjectsHelperPatch)
ProjectsHelper.send(:include, RedmineMessenger::Patches::ProjectsHelperPatch)
end