# frozen_string_literal: true
require 'net/http'
class MessengerTeamsJob < ApplicationJob
  include ActionView::Helpers
  include IssuesHelper
  include CustomFieldsHelper

  def perform(msg, teams_channel)
    begin
      microsoft_access_token = RedmineMessenger.settings[:microsoft_access_token]
      return if microsoft_access_token.blank?

      headers = {
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer ' + microsoft_access_token
      }
      url = "https://graph.microsoft.com/v1.0/chats/#{teams_channel}/messages"
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.path, headers)
      
      detail = []
      text = msg

      # if options[:attachment].present?
      #   if options[:attachment][:fields].present?
      #     options[:attachment][:fields].each {|x| detail << x[:title] + " : " + x[:value] }
      #   end
      #   text += "\r\n" + options[:attachment][:text] if options[:attachment][:text].present?
      # end

      # detailTitle = ""
      # if detail != []
      #   detailTitle = "Detail"
      # end
      
      content = {
          "body":{
            "contentType": "html",
            "content": msg
          }
        }.to_json

      request.body = content
      response = http.request(request)
    rescue => e
      Rails.logger.info "send_message_to_teams_error #{e}"
    end
  end
  
end
