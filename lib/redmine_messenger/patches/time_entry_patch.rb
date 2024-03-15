module RedmineMessenger
    module Patches
        module TimeEntryPatch
            def self.included(base)
                base.send(:include, InstanceMethods)

                base.class_eval do
                  unloadable
                  after_save :notify_pm
                  after_destroy :notify_pm
                end
            end
            module InstanceMethods
                def notify_pm
                  estimated_hours = self.issue.estimated_hours
                  return if estimated_hours.to_i.zero?
                  spent_hours = self.issue.time_entries.pluck(:hours).sum
                  spent_per = ((spent_hours / estimated_hours.to_f) * 100).to_i
                  if spent_per >= 80
                    channels = Messenger.channels_for_project project
                    url = Messenger.url_for_project project
                    teams_channel = Messenger.teams_channel(project)

                    Rails.logger.info "Project Channel #{teams_channel} *******"
                    if teams_channel.present?
                      MessengerTeamsJob.perform_later("#{spent_per}% of estimated time has been spent on ticket <a href='#{Messenger.object_url(issue)}'>##{self.issue_id}</a>", teams_channel)
                    end

                    Messenger.speak(l(:label_messenger_overtime_issue,
                            time: "#{spent_per}",
                            url: self.issue.send(:send_messenger_mention_url,project, "")),
                          channels, url, attachment: {}, project: project)
                    Rails.logger.info "Send notification to the zoho"

                    #send the updated issue to zoho
                    Messenger.speak_zoho(l(:label_messenger_overtime_issue,
                                time: "#{spent_per}",
                                url: self.issue.send(:send_messenger_mention_zoho_url,project, "")), Messenger.zoho_message_url(project), attachment: {}, project: project)

                  end
                end
            end
        end
    end
end
unless TimeEntry.included_modules.include?(RedmineMessenger::Patches::TimeEntryPatch)
    TimeEntry.send(:include, RedmineMessenger::Patches::TimeEntryPatch)
end