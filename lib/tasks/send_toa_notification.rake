namespace :send do
  namespace :toa do
    desc 'Send notification to project channel if the TOA less than 0'
    task notification: :environment do
      projects = Project.active
      projects.each do |project|
        begin
          Rails.logger.info "send_toa_notification Processing project #{project.name}"
          toa_value = project.custom_field_value(27)
          if toa_value.present?
            if toa_value.to_i <= 0
              teams_channel = Messenger.teams_channel(project)
              if teams_channel.present?
                MessengerTeamsJob.perform_later("<div><div>\n<div><p>The TOA on this project<a href='#{Messenger.object_url(project)}'>#{project.name}</a> is lower than 1 hour</div></div>", teams_channel)
              end
            end
          end
        rescue => e
          Rails.logger.info "send_toa_notification Error in Processing #{project.id} #{e}"
        end
      end
    end
  end
end