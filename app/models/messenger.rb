require 'net/http'

class Messenger  
  include ActionView::Helpers
  include IssuesHelper
  include CustomFieldsHelper
  # include Redmine::I18n

  def self.markup_format(text)
    # TODO: output format should be markdown, but at the moment there is no
    #       solution without using pandoc (http://pandoc.org/), which requires
    #       packages on os level
    #
    # Redmine::WikiFormatting.html_parser.to_text(text)
    ERB::Util.html_escape(text)
  end

  def self.default_url_options
    { only_path: true, script_name: Redmine::Utils.relative_url_root }
  end

  def self.speak(msg, channels, url, options)
    url ||= RedmineMessenger.settings[:messenger_url]

    return if url.blank?
    return if channels.blank?

    params = {
      text: msg,
      link_names: 1
    }

    username = Messenger.textfield_for_project(options[:project], :messenger_username)
    params[:username] = username if username.present?
    params[:attachments] = [options[:attachment]] if options[:attachment]&.any?

    icon = Messenger.textfield_for_project(options[:project], :messenger_icon)
    if icon.present?
      if icon.start_with? ':'
        params[:icon_emoji] = icon
      else
        params[:icon_url] = icon
      end
    end

    channels.each do |channel|
      uri = URI(url)
      params[:channel] = channel
      http_options = { use_ssl: uri.scheme == 'https' }
      http_options[:verify_mode] = OpenSSL::SSL::VERIFY_NONE unless RedmineMessenger.setting?(:messenger_verify_ssl)

      begin
        req = Net::HTTP::Post.new(uri)
        req.set_form_data(payload: params.to_json)
        Net::HTTP.start(uri.hostname, uri.port, http_options) do |http|
          response = http.request(req)
          Rails.logger.warn(response) unless [Net::HTTPSuccess, Net::HTTPRedirection, Net::HTTPOK].include? response
        end
      rescue StandardError => e
        Rails.logger.warn("cannot connect to #{url}")
        Rails.logger.warn(e)
      end
    end
  end

  #for zoho integration
  def self.speak_zoho(msg, url, options)
    Rails.logger.info "speak zoho logger"
    zoho_access_token = Messenger.get_access_token
    return if zoho_access_token.blank?
    # zoho_access_token = RedmineMessenger.settings[:zoho_authtoken]
    headers = {
        'Content-Type' => 'application/json',
        'Authorization' => 'Zoho-oauthtoken ' + zoho_access_token
    }
    uri = URI(url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, headers)
    
    detail = []
    text = msg

    if options[:attachment].present?
      if options[:attachment][:fields].present?
        options[:attachment][:fields].each {|x| detail << x[:title] + " : " + x[:value] }
      end
      text += "\r\n" + options[:attachment][:text] if options[:attachment][:text].present?
    end

    detailTitle = ""
    if detail != []
      detailTitle = "Detail"
    end
    
    content = {
      "text": text,
      "card": {
        "theme": "modern-inline"
      },
      "slides": [
        {
          "type": "list",
          "title": detailTitle ,
          "data": detail
        }
      ]
    }.to_json

    request.body = content
    response = http.request(request)
  end

  def self.get_access_token
   params = {}
   response = nil
   refresh_token = RedmineMessenger.settings[:zoho_refresh_token]
   client_id = RedmineMessenger.settings[:zoho_client_id]
   client_secret = RedmineMessenger.settings[:zoho_client_secret]
   # params[:redirect_uri] = 'https://support.targetintegration.com/'
   # params[:scope] = 'ZohoCliq.Channels.CREATE,ZohoCliq.Channels.READ,ZohoCliq.Channels.UPDATE'
   grant_type = 'refresh_token'
   uri = URI("https://accounts.zoho.com/oauth/v2/token?refresh_token=#{refresh_token}&client_id=#{client_id}&client_secret=#{client_secret}&grant_type=refresh_token")
   http_options = { use_ssl: uri.scheme == 'https' }
   req = Net::HTTP::Post.new(uri)
   # req.set_form_data(params)
   Net::HTTP.start(uri.hostname, uri.port, http_options) do |http|
     response = http.request(req)
     Rails.logger.warn(response) unless [Net::HTTPSuccess, Net::HTTPRedirection, Net::HTTPOK].include? response
   end
   res = JSON.parse(response.body)
   return res.try(:[],"access_token")
 end

  def self.zoho_message_url(proj)
    zoho_token = RedmineMessenger.settings[:zoho_authtoken]
    channel = RedmineMessenger.settings[:zoho_channel]
    pm = MessengerSetting.find_by(project_id: proj.id)
    channel = pm.zoho_channel if !pm.nil? && pm.zoho_channel.present?
    return "https://cliq.zoho.com/api/v2/channelsbyname/" + channel + "/message"
  end

  def self.object_url(obj)
    if Setting.host_name.to_s =~ %r{\A(https?\://)?(.+?)(\:(\d+))?(/.+)?\z}i
      host = Regexp.last_match(2)
      port = Regexp.last_match(4)
      prefix = Regexp.last_match(5)
      Rails.application.routes.url_for(obj.event_url(host: host, protocol: Setting.protocol, port: port, script_name: prefix))
    else
      Rails.application.routes.url_for(obj.event_url(host: Setting.host_name, protocol: Setting.protocol, script_name: ''))
    end
  end

  def self.teams_channel(proj)
    pm = MessengerSetting.find_by(project_id: proj.id)
    channel = pm.teams_channel if !pm.nil? && pm.teams_channel.present?
  end

  def teams_message(issue, type, user)
    if type == 'created'
      "<div><div>\n<div><p><a href='#{Messenger.object_url(issue.project)}'>#{issue.project.name}</a> issue <a href='#{Messenger.object_url(issue)}'>#{issue.tracker.name} #{issue.id}: #{issue.subject}</a> created by #{user.name}</p><hr>#{textilizable(issue, :description, :only_path => false)}<p>#{render_email_issue_attributes(issue, issue.author, true)}</p>\n\n</div>\n\n\n</div>\n</div>"
    else
      "<div><div>\n<div><p><a href='#{Messenger.object_url(issue.project)}'>#{issue.project.name}</a> issue <a href='#{Messenger.object_url(issue)}'>#{issue.tracker.name} #{issue.id}: #{issue.subject}</a> updated by #{user.name}</p><hr><p>#{render_email_issue_attributes(issue, issue.author, true)} #{issue.current_journal.present? ? textilizable(issue.current_journal, :notes, :only_path => false) : ''}</p>\n\n</div>\n\n\n</div>\n</div>"
    end
  end

  def teams_common_message(object, type, user)
    if type == 'created'
      "<div><div>\n<div><p><a href='#{Messenger.object_url(object.project)}'>#{object.project.name}</a> #{object.class.to_s.downcase} <a href='#{Messenger.object_url(object)}'>#{object.try(:name).present? ? object.try(:name) : object.try(:title)}</a> created by #{user.name}</p></div>\n</div></div>"
    else
      "<div><div>\n<div><p><a href='#{Messenger.object_url(object.project)}'>#{object.project.name}</a> #{object.class.to_s.downcase} <a href='#{Messenger.object_url(object)}'>#{object.try(:name).present? ? object.try(:name) : object.try(:title)}</a> updated by #{user.name}</p></div>\n</div></div>"
    end
  end

  def self.update_microsoft_token
    if RedmineMessenger.settings[:microsoft_refresh_token].present?
      access_uri = URI("https://login.microsoftonline.com/#{RedmineMessenger.settings[:microsoft_tennant_id]}/oauth2/v2.0/token")
      access_params = {'client_id' => RedmineMessenger.settings[:microsoft_client_id],
      'client_secret' => RedmineMessenger.settings[:microsoft_secret],
      'redirect_uri' => 'https://targetintegration.com',
      'scope' => 'https://graph.microsoft.com/.default offline_access',
      'grant_type' => 'refresh_token',
      'refresh_token' => RedmineMessenger.settings[:microsoft_refresh_token]}
      access_encoded_form = URI.encode_www_form(access_params)
      access_headers = { content_type: "application/x-www-form-urlencoded" }
      access_http = Net::HTTP.new(access_uri.host, access_uri.port)
      access_http.use_ssl = true
      access_token_response = access_http.request_post(access_uri.path, access_encoded_form, access_headers)
      access_token_data = JSON.parse(access_token_response.body)
      if access_token_data['access_token'].present?
        setting = Setting.where(name: 'plugin_redmine_messenger').first
        setting_value = setting.value
        setting_value['microsoft_refresh_token'] = access_token_data['refresh_token']
        setting_value['microsoft_access_token'] = access_token_data['access_token']
        setting.value = setting_value
        setting.save
        Rails.logger.info "Microsoft_Token_Updated_Success Refresh token updated successfully"
      else
        Rails.logger.info "Microsoft_Token_Update error response got #{access_token_response}"  
      end
    else
      Rails.logger.info "Microsoft_Token_Update Refresh token not found. Please update it from the plugin configuration"
    end
  end

  def self.zoho_message_url(proj)
    zoho_token = RedmineMessenger.settings[:zoho_authtoken]
    channel = RedmineMessenger.settings[:zoho_channel]
    pm = MessengerSetting.find_by(project_id: proj.id)
    channel = pm.zoho_channel if !pm.nil? && pm.zoho_channel.present?
    return "https://cliq.zoho.com/api/v2/channelsbyname/" + channel + "/message"
  end

  def self.object_url(obj)
    if Setting.host_name.to_s =~ %r{\A(https?\://)?(.+?)(\:(\d+))?(/.+)?\z}i
      host = Regexp.last_match(2)
      port = Regexp.last_match(4)
      prefix = Regexp.last_match(5)
      Rails.application.routes.url_for(obj.event_url(host: host, protocol: Setting.protocol, port: port, script_name: prefix))
    else
      Rails.application.routes.url_for(obj.event_url(host: Setting.host_name, protocol: Setting.protocol, script_name: ''))
    end
  end

  def self.url_for_project(proj)
    return if proj.blank?

    # project based
    pm = MessengerSetting.find_by(project_id: proj.id)
    return pm.messenger_url if !pm.nil? && pm.messenger_url.present?

    # parent project based
    parent_url = url_for_project(proj.parent)
    return parent_url if parent_url.present?
    # system based
    return RedmineMessenger.settings[:messenger_url] if RedmineMessenger.settings[:messenger_url].present?

    nil
  end

  def self.textfield_for_project(proj, config)
    return if proj.blank?

    # project based
    pm = MessengerSetting.find_by(project_id: proj.id)
    return pm.send(config) if !pm.nil? && pm.send(config).present?

    default_textfield(proj, config)
  end

  def self.default_textfield(proj, config)
    # parent project based
    parent_field = textfield_for_project(proj.parent, config)
    return parent_field if parent_field.present?
    return RedmineMessenger.settings[config] if RedmineMessenger.settings[config].present?

    ''
  end

  def self.channels_for_project(proj)
    return [] if proj.blank?

    # project based
    pm = MessengerSetting.find_by(project_id: proj.id)
    if !pm.nil? && pm.messenger_channel.present?
      return [] if pm.messenger_channel == '-'

      return pm.messenger_channel.split(',').map!(&:strip).uniq
    end
    default_project_channels(proj)
  end

  def self.default_project_channels(proj)
    # parent project based
    parent_channel = channels_for_project(proj.parent)
    return parent_channel if parent_channel.present?
    # system based
    if RedmineMessenger.settings[:messenger_channel].present? &&
       RedmineMessenger.settings[:messenger_channel] != '-'
      return RedmineMessenger.settings[:messenger_channel].split(',').map!(&:strip).uniq
    end

    []
  end

  def self.setting_for_project(proj, config)
    return false if proj.blank?

    @setting_found = 0
    # project based
    pm = MessengerSetting.find_by(project_id: proj.id)
    unless pm.nil? || pm.send(config).zero?
      @setting_found = 1
      return false if pm.send(config) == 1
      return true if pm.send(config) == 2
      # 0 = use system based settings
    end
    default_project_setting(proj, config)
  end

  def self.default_project_setting(proj, config)
    if proj.present? && proj.parent.present?
      parent_setting = setting_for_project(proj.parent, config)
      return parent_setting if @setting_found == 1
    end
    # system based
    return true if RedmineMessenger.settings[config].present? && RedmineMessenger.setting?(config)

    false
  end

  def self.detail_to_field(detail)
    field_format = nil
    key = nil
    escape = true

    if detail.property == 'cf'
      key = CustomField.find(detail.prop_key).name rescue nil
      title = key
      field_format = CustomField.find(detail.prop_key).field_format rescue nil
    elsif detail.property == 'attachment'
      key = 'attachment'
      title = I18n.t :label_attachment
    else
      key = detail.prop_key.to_s.sub('_id', '')
      title = if key == 'parent'
                I18n.t "field_#{key}_issue"
              else
                I18n.t "field_#{key}"
              end
    end

    short = true
    value = detail.value.to_s

    case key
    when 'title', 'subject', 'description'
      short = false
    when 'tracker'
      tracker = Tracker.find(detail.value)
      value = tracker.to_s if tracker.present?
    when 'project'
      project = Project.find(detail.value)
      value = project.to_s if project.present?
    when 'status'
      status = IssueStatus.find(detail.value)
      value = status.to_s if status.present?
    when 'priority'
      priority = IssuePriority.find(detail.value)
      value = priority.to_s if priority.present?
    when 'category'
      category = IssueCategory.find(detail.value)
      value = category.to_s if category.present?
    when 'assigned_to'
      user = User.find(detail.value)
      value = user.to_s if user.present?
    when 'fixed_version'
      fixed_version = Version.find(detail.value)
      value = fixed_version.to_s if fixed_version.present?
    when 'attachment'
      attachment = Attachment.find(detail.prop_key)
      value = "<#{Messenger.object_url attachment}|#{ERB::Util.html_escape(attachment.filename)}>" if attachment.present?
      escape = false
    when 'parent'
      issue = Issue.find(detail.value)
      value = "<#{Messenger.object_url issue}|#{ERB::Util.html_escape(issue)}>" if issue.present?
      escape = false
    end

    if detail.property == 'cf' && field_format == 'version'
      version = Version.find(detail.value)
      value = version.to_s if version.present?
    end

    value = if value.present?
              if escape
                ERB::Util.html_escape(value)
              else
                value
              end
            else
              '-'
            end

    result = { title: title, value: value }
    result[:short] = true if short
    result
  end

  def self.mentions(project, text)
    names = []
    Messenger.textfield_for_project(project, :default_mentions)
             .split(',').each { |m| names.push m.strip }
    names += extract_usernames(text) unless text.nil?
    names.present? ? ' To: ' + names.uniq.join(', ') : nil
  end

  def self.extract_usernames(text)
    text = '' if text.nil?
    # messenger usernames may only contain lowercase letters, numbers,
    # dashes, dots and underscores and must start with a letter or number.
    text.scan(/@[a-z0-9][a-z0-9_\-.]*/).uniq
  end
end
