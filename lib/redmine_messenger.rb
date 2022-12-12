  module RedmineMessenger
    REDMINE_CONTACTS_SUPPORT = Redmine::Plugin.installed?('redmine_contacts') ? true : false
    REDMINE_DB_SUPPORT = Redmine::Plugin.installed?('redmine_db') ? true : false
    # this does not work at the moment, because redmine loads passwords after messener plugin
    REDMINE_PASSWORDS_SUPPORT = Redmine::Plugin.installed?('redmine_passwords') ? true : false

    @@zoho_token=""

    def self.zoho_token
      @@zoho_token
    end
    
    def self.zoho_token=zoho_token
      @@zoho_token = zoho_token
    end

    def self.settings
      if Setting[:plugin_redmine_messenger].class == Hash
        if Rails.version >= '5.2'
          # convert Rails 4 data
          new_settings = ActiveSupport::HashWithIndifferentAccess.new(Setting[:plugin_redmine_messenger])
          Setting.plugin_redmine_messenger = new_settings
          new_settings
        else
          ActionController::Parameters.new(Setting[:plugin_redmine_messenger])
        end
      else
        # Rails 5 uses ActiveSupport::HashWithIndifferentAccess
        Setting[:plugin_redmine_messenger]
      end
    end

    def self.setting?(value)
      return true if settings[value].to_i == 1
      false
    end

    def self.logintoZoho
      zoho_username = settings['zoho_username']
      zoho_userpwd = settings['zoho_userpwd']
      zoho_channel = settings['zoho_channel']
      
      params = {
          SCOPE:        'ZohoCliq/InternalAPI',
          EMAIL_ID:     zoho_username,
          PASSWORD:     zoho_userpwd,
          display_name: 'ZOHOCLIQ'
      }

      uri = URI.parse('https://accounts.zoho.com/apiauthtoken/nb/create')
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true

      request = Net::HTTP::Post.new(uri.path, {'Content-Type' => 'text/json'})
      request.set_form_data(params)

      # send the request
      response = http.request(request)
      res_body = response.body.split("\n")
      self.zoho_token = res_body[2].split('=')[1]
      Rails.logger.warn(response) unless [Net::HTTPSuccess, Net::HTTPRedirection, Net::HTTPOK].include? response
    end
  end
