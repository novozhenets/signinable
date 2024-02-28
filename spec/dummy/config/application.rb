# frozen_string_literal: true

require File.expand_path('boot', __dir__)

require 'active_record/railtie'

Bundler.require(*Rails.groups)
require 'signinable'

module Dummy
  class Application < Rails::Application
    config.load_defaults 7.0
  end
end
