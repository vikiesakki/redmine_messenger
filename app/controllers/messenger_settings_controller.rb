class MessengerSettingsController < ApplicationController
  before_action :find_project_by_project_id, only: :update
  before_action :authorize, only: :update

  accept_api_auth :notify_all

  def notify_all
    request_ip = request.remote_ip
    channel_name = request.headers["ChannelName"]
    message = request.headers["Message"]
    respond_to do |format|
      format.api do 
        if RedmineMessenger.settings[:whitelist_ips].split(',').include?(request_ip)
          if channel_name.present? && message.present? 
            MessengerTeamsJob.perform_later(message, channel_name)
            render json: {success: "Message sent success"}
          else
            render json: {error: "Invalid channel or message"}  
          end
        else
          render json: {error: "IP is not whitelisted"}
        end
      end
    end
  end

  def update
    setting = MessengerSetting.find_or_create(@project.id)
    if setting.update(allowed_params)
      flash[:notice] = l(:notice_successful_update)
      redirect_to settings_project_path(@project, tab: 'messenger')
    else
      flash[:error] = setting.errors.full_messages.flatten.join("\n")
      respond_to do |format|
        format.html { redirect_back_or_default(settings_project_path(@project, tab: 'messenger')) }
        format.api  { render_validation_errors(setting) }
      end
    end
  end

  private

  def allowed_params
    params.require(:setting).permit :messenger_url,
                                    :messenger_icon,
                                    :messenger_channel,
                                    :messenger_username,
                                    :messenger_verify_ssl,
                                    :zoho_channel,
                                    :auto_mentions,
                                    :default_mentions,
                                    :display_watchers,
                                    :teams_channel,
                                    :post_updates,
                                    :new_include_description,
                                    :updated_include_description,
                                    :post_private_issues,
                                    :post_private_notes,
                                    :post_wiki,
                                    :post_wiki_updates,
                                    :post_db,
                                    :post_db_updates,
                                    :post_private_db,
                                    :post_contact,
                                    :post_contact_updates,
                                    :post_private_contacts,
                                    :post_password,
                                    :post_password_updates
  end
end
