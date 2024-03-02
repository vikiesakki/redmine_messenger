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
      chat_headers = {
          'Authorization' => 'Bearer ' + microsoft_access_token
      }
      chat_record = {}
      chat_url = "https://graph.microsoft.com/v1.0/users/882d7d1f-37fc-46f7-b8ca-96d875f4e1c7/chats"
      chat_uri = URI(chat_url)
      chat_http = Net::HTTP.new(chat_uri.host, chat_uri.port)
      chat_http.use_ssl = true
      chat_request = Net::HTTP::Get.new(chat_uri.path, chat_headers)
      chat_response = chat_http.request(chat_request)
      chats = JSON.parse(chat_response.body)
      # Rails.logger.info "chat_response_from_microsoft #{chats}"
      if chats['value'].present?
        chats['value'].each do |chat|
          if chat['topic'] == teams_channel
            chat_record = chat
            break
          end
        end
      else
        Rails.logger.info "send_message_to_teams Chat not found #{teams_channel}"
        return 
      end

      if chat_record.blank?
        Rails.logger.info "send_message_to_teams Chat not found #{teams_channel}"
        return 
      end

      headers = {
          'Content-Type' => 'application/json',
          'Authorization' => 'Bearer ' + microsoft_access_token
      }
      url = "https://graph.microsoft.com/v1.0/chats/#{chat_record['id']}/messages"
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
