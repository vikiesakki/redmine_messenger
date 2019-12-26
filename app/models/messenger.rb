require 'net/http'

class Messenger
  include Redmine::I18n

  class << self
    def markup_format(text)
      # TODO: output format should be markdown, but at the moment there is no
      #       solution without using pandoc (http://pandoc.org/), which requires
      #       packages on os level
      #
      # Redmine::WikiFormatting.html_parser.to_text(text)

      text = text.to_s
      text.gsub!('&', '&amp;')
      text.gsub!('<', '&lt;')
      text.gsub!('>', '&gt;')

      text
    end

    def default_url_options
      { only_path: true, script_name: Redmine::Utils.relative_url_root }
    end

    def speak(msg, channels, url, options)
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

    def object_url(obj)
      if Setting.host_name.to_s =~ %r{\A(https?\://)?(.+?)(\:(\d+))?(/.+)?\z}i
        host = Regexp.last_match(2)
        port = Regexp.last_match(4)
        prefix = Regexp.last_match(5)
        Rails.application.routes.url_for(obj.event_url(host: host, protocol: Setting.protocol, port: port, script_name: prefix))
      else
        Rails.application.routes.url_for(obj.event_url(host: Setting.host_name, protocol: Setting.protocol, script_name: ''))
      end
    end

    def url_for_project(proj)
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

    def textfield_for_project(proj, config)
      return if proj.blank?

      # project based
      pm = MessengerSetting.find_by(project_id: proj.id)
      return pm.send(config) if !pm.nil? && pm.send(config).present?

      default_textfield(proj, config)
    end

    def default_textfield(proj, config)
      # parent project based
      parent_field = textfield_for_project(proj.parent, config)
      return parent_field if parent_field.present?
      return RedmineMessenger.settings[config] if RedmineMessenger.settings[config].present?

      ''
    end

    def channels_for_project(proj)
      return [] if proj.blank?

      # project based
      pm = MessengerSetting.find_by(project_id: proj.id)
      if !pm.nil? && pm.messenger_channel.present?
        return [] if pm.messenger_channel == '-'

        return pm.messenger_channel.split(',').map!(&:strip).uniq
      end
      default_project_channels(proj)
    end

    def setting_for_project(proj, config)
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

    def default_project_setting(proj, config)
      if proj.present? && proj.parent.present?
        parent_setting = setting_for_project(proj.parent, config)
        return parent_setting if @setting_found == 1
      end
      # system based
      return true if RedmineMessenger.settings[config].present? && RedmineMessenger.setting?(config)

      false
    end

    def detail_to_field(detail)
      field_format = nil
      key = nil
      escape = true
      value = detail.value.to_s

      if detail.property == 'cf'
        key = CustomField.find(detail.prop_key)&.name
        unless key.nil?
          title = key
          field_format = CustomField.find(detail.prop_key)&.field_format
          value = IssuesController.helpers.format_value(detail.value, detail.custom_field) if detail.value.present?
        end
      elsif detail.property == 'attachment'
        key = 'attachment'
        title = I18n.t :label_attachment
        value = detail.value.to_s
      else
        key = detail.prop_key.to_s.sub('_id', '')
        title = if key == 'parent'
                  I18n.t "field_#{key}_issue"
                else
                  I18n.t "field_#{key}"
                end
        value = detail.value.to_s
      end

      short = true

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
        value = "<#{Messenger.object_url attachment}|#{markup_format(attachment.filename)}>" if attachment.present?
        escape = false
      when 'parent'
        issue = Issue.find(detail.value)
        value = "<#{Messenger.object_url issue}|#{markup_format(issue)}>" if issue.present?
        escape = false
      end

      if detail.property == 'cf' && field_format == 'version'
        version = Version.find(detail.value)
        value = version.to_s if version.present?
      end

      value = if value.present?
                if escape
                  markup_format(value)
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

    def mentions(project, text)
      names = []
      Messenger.textfield_for_project(project, :default_mentions)
               .split(',').each { |m| names.push m.strip }
      names += extract_usernames(text) unless text.nil?
      names.present? ? ' To: ' + names.uniq.join(', ') : nil
    end

    private

    def extract_usernames(text)
      text = '' if text.nil?
      # messenger usernames may only contain lowercase letters, numbers,
      # dashes, dots and underscores and must start with a letter or number.
      text.scan(/@[a-z0-9][a-z0-9_\-.]*/).uniq
    end

    def default_project_channels(proj)
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
  end
end
