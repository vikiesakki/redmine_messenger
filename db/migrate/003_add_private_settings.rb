# frozen_string_literal: true

class AddPrivateSettings < ActiveRecord::Migration[4.2]
  def change
    change_table :messenger_settings, bulk: true do |t|
      t.integer :post_private_contacts, default: 0, null: false
      t.integer :post_private_db, default: 0, null: false
    end
  end
end
