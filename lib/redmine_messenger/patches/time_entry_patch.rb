module RedmineMessenger
    module Patches
        module TimeEntryPatch
            def self.included(base)
                base.send(:include, InstanceMethods)

                base.class_eval do
                  unloadable
                  after_save :notify_pm
                  after_destroy :notify_pm

                  after_save :notify_time_on_account

                end
            end
            module InstanceMethods
                def notify_pm
                  setting = MessengerSetting.where(project_id: project.id).first
                  return if setting.disable_chat

                  estimated_hours = self.issue.estimated_hours
                  return if estimated_hours.to_i.zero?
                  spent_hours = self.issue.time_entries.pluck(:hours).sum
                  spent_per = ((spent_hours / estimated_hours.to_f) * 100).to_i
                  if spent_per >= 80
                    channels = Messenger.channels_for_project project
                    url = Messenger.url_for_project project
                    teams_channel = Messenger.teams_channel(project)

                    Rails.logger.info "notify_pm Project Channel #{teams_channel} *******"
                    if teams_channel.present?
                      MessengerTeamsJob.perform_later("#{spent_per}% of estimated time has been spent on ticket <a href='#{Messenger.object_url(issue)}'>##{self.issue_id}</a>", teams_channel)
                    end

                    Messenger.speak(l(:label_messenger_overtime_issue,
                            time: "#{spent_per}",
                            url: self.issue.send(:send_messenger_mention_url,project, "")),
                          channels, url, attachment: {}, project: project)
                    Rails.logger.info "notify_pm Send notification to the zoho"

                    #send the updated issue to zoho
                    Messenger.speak_zoho(l(:label_messenger_overtime_issue,
                                time: "#{spent_per}",
                                url: self.issue.send(:send_messenger_mention_zoho_url,project, "")), Messenger.zoho_message_url(project), attachment: {}, project: project)

                  end
                end

                def notify_time_on_account
                    setting = MessengerSetting.where(project_id: project.id).first
                    return if setting.disable_chat

                    field_team = CustomField.find 16
                    time_on_account = self.project.custom_field_value(27)
                    external_project = self.project.custom_field_value(16)
                    tm_project = self.project.custom_field_value(13)
                    option = field_team.enumerations.find { |v| v.id == external_project.to_i }
                    return if option.try(:name).to_s.downcase == "internal"
                    if time_on_account.to_i < 5 && (tm_project.to_s.downcase.include?("t&m"))
                        channels = Messenger.channels_for_project project
                        url = Messenger.url_for_project project
                        teams_channel = Messenger.teams_channel(project)

                        Rails.logger.info "notify_time_on_account Project Channel #{teams_channel} *******"
                        if teams_channel.present?
                          MessengerTeamsJob.perform_later("The TOA on this project (#{time_on_account.to_i}) is lower than 5 hour <a href='#{Messenger.object_url(self.project)}'>#{self.project.name}</a>", teams_channel)
                        end
                    end
                end
            end
        end
    end
end
unless TimeEntry.included_modules.include?(RedmineMessenger::Patches::TimeEntryPatch)
    TimeEntry.send(:include, RedmineMessenger::Patches::TimeEntryPatch)
end