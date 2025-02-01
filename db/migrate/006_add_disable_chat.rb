class AddDisableChat < ActiveRecord::Migration[6.1]
  def change
    unless column_exists?(:messenger_settings, :disable_chat)
      add_column :messenger_settings, :disable_chat, :boolean, default: 0
    end
  end
end
