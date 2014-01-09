require 'rails/generators/migration'

class SigninableGenerator < Rails::Generators::Base
  include Rails::Generators::Migration
  source_root File.expand_path('../templates', __FILE__)

  def self.next_migration_number(path)
    Time.now.utc.strftime("%Y%m%d%H%M%S")
  end

  def create_model_file
    template "signin.rb", "app/models/signin.rb"
    migration_template "create_signins.rb", "db/migrate/create_signins.rb"
  end
end
