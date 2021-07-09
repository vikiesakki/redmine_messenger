# frozen_string_literal: true

module RedmineMessenger
  module Patches
    module ProjectPatch
      extend ActiveSupport::Concern

      included do
        has_one :messenger_setting, dependent: :destroy
      end
    end
  end
end
