require 'rubygems'
require 'timecop'
require 'factory_girl_rails'

ENV['RAILS_ENV'] ||= 'test'
require File.expand_path('../../config/environment', __FILE__)
require 'rspec/rails'
require 'rspec/autorun'

Dir[Rails.root.join('spec/support/**/*.rb')].each {|f| require f}

ActiveRecord::Migration.verbose = false
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
load(File.expand_path(File.dirname(__FILE__) + '/../../dummy/db/schema.rb'))

require File.expand_path(File.dirname(__FILE__) + '/../../../lib/generators/signinable/templates/create_signins')
CreateSignins.up
load(File.expand_path(File.dirname(__FILE__) + '/../../../lib/generators/signinable/templates/signin.rb'))

RSpec.configure do |config|
  config.use_transactional_fixtures = false

  config.infer_base_class_for_anonymous_controllers = false

  config.order = 'random'
end
