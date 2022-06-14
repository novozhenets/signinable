# frozen_string_literal: true

ENV['RAILS_ENV'] ||= 'test'

require File.expand_path('dummy/config/environment', __dir__)

require 'spec_helper'
require 'rspec/rails'

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].sort.each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true

  config.infer_spec_type_from_file_location!

  config.filter_rails_from_backtrace!

  config.include FactoryBot::Syntax::Methods
end
