# frozen_string_literal: true

migration_kls = Rails::VERSION::MAJOR > 4 ? ActiveRecord::Migration[5.0] : ActiveRecord::Migration

class AddCustomDataToSigins < migration_kls
  def change
    if ActiveRecord::Base.connection.instance_values['config'][:adapter] == 'postgresql'
      add_column :signins, :custom_data, :jsonb, null: false, default: {}
    else
      add_column :signins, :custom_data, :string, null: false, default: {}.to_json
    end
  end
end
