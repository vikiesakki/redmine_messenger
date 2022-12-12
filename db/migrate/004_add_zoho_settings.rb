class AddZohoSettings < Rails.version < '5.2' ? ActiveRecord::Migration : ActiveRecord::Migration[4.2]
  def change
    add_column :messenger_settings, :zoho_channel, :string
  end
end
