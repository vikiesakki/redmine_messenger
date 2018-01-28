class AddDefaultMentions < ActiveRecord::Migration
  def change
    add_column :messenger_settings, :default_mentions, :string
  end
end
