# Redmine Messenger plugin for Redmine

class MessengerSetting < ActiveRecord::Base
  include Redmine::SafeAttributes
  belongs_to :project

  validates :project_id, presence: true

  safe_attributes 'messenger_url',
                  'messenger_icon',
                  'messenger_channel',
                  'messenger_username',
                  'messenger_verify_ssl',
                  'auto_mentions',
                  'default_mentions',
                  'display_watchers',
                  'post_updates',
                  'new_include_description',
                  'updated_include_description',
                  'post_private_issues',
                  'post_private_notes',
                  'post_wiki',
                  'post_wiki_updates',
                  'post_db',
                  'post_db_updates',
                  'post_private_db',
                  'post_contact',
                  'post_contact_updates',
                  'post_private_contacts',
                  'post_password',
                  'post_password_updates'

  attr_protected :id

  def self.find_or_create(p_id)
    setting = MessengerSetting.find_by(project_id: p_id)
    unless setting
      setting = MessengerSetting.new
      setting.project_id = p_id
      setting.save!
    end

    setting
  end
end
