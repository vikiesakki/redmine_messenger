# require '../redmine_issue_tracker/services/POA_API_service'
namespace :update do
  namespace :teams do
    desc 'Updating Microsoft Refresh token'
    task refresh_token: :environment do
      Messenger.update_microsoft_token
    end
  end
end