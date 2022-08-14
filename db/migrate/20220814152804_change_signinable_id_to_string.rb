# frozen_string_literal: true

migration_kls = Rails::VERSION::MAJOR > 4 ? ActiveRecord::Migration[5.0] : ActiveRecord::Migration
class ChangeSigninableIdToString < migration_kls
  def self.up
    change_column :signins, :signinable_id, :string, null: false
  end

  def self.down
    change_column :signins, :signinable_id, :integer, null: false
  end
end
