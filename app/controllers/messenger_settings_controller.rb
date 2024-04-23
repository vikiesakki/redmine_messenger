class MessengerSettingsController < ApplicationController
  before_action :find_project_by_project_id, only: [:update, :create_chat]
  before_action :authorize, only: [:update, :create_chat]

  accept_api_auth :notify_all

  def notify_all
    request_ip = request.remote_ip
    channel_name = request.headers["ChannelName"]
    message = request.headers["Message"]
    respond_to do |format|
      format.api do 
        # if RedmineMessenger.settings[:whitelist_ips].split(',').include?(request_ip)
          if channel_name.present? && message.present? 
            MessengerTeamsJob.perform_later(message, channel_name)
            render json: {success: "Message sent success"}
          else
            render json: {error: "Invalid channel or message"}  
          end
        # else
        #   render json: {error: "IP is not whitelisted"}
        # end
      end
    end
  end

  def create_chat
    chat_request = { "chatType"=> "group", "topic"=> @project.name }
    chat_request["members"] = [{"@odata.type"=> "#microsoft.graph.aadUserConversationMember", "roles"=> ["owner"], "user@odata.bind"=>"https://graph.microsoft.com/v1.0/users('882d7d1f-37fc-46f7-b8ca-96d875f4e1c7')"},{"@odata.type"=> "#microsoft.graph.aadUserConversationMember", "roles"=> ["owner"], "user@odata.bind"=>"https://graph.microsoft.com/v1.0/users('3757671c-9b01-4c6e-a0b8-fdfb130c8755')"}]
    microsoft_access_token = RedmineMessenger.settings[:microsoft_access_token]
    return if microsoft_access_token.blank?
    headers = {
        'Content-Type' => 'application/json',
        'Authorization' => 'Bearer ' + microsoft_access_token
    }
    uri = URI('https://graph.microsoft.com/v1.0/chats')
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, headers)
    content = chat_request.to_json
    request.body = content
    response = http.request(request)
    res = JSON.parse(response.body)
    if res['id'].present?
      setting = MessengerSetting.where(project_id: @project.id).first
      setting.update(teams_channel: res['id'])
      flash[:notice] = "Channel created successfully"
    else
      flash[:error] = response.body
    end
    redirect_back_or_default(settings_project_path(@project, tab: 'messenger'))
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
