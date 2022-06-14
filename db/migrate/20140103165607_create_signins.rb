# frozen_string_literal: true

migration_kls = Rails::VERSION::MAJOR > 4 ? ActiveRecord::Migration[5.0] : ActiveRecord::Migration
class CreateSignins < migration_kls
  def self.up
    create_table :signins do |t|
      t.integer   :signinable_id, null: false
      t.string    :signinable_type, null: false
      t.string    :token, null: false
      t.string    :referer, default: ''
      t.string    :user_agent, default: ''
      t.string    :ip, null: false
      t.datetime  :expiration_time
      t.timestamps
    end

    if ActiveRecord::Base.connection.instance_values['config'][:adapter] == 'postgresql'
      execute 'ALTER TABLE signins ALTER COLUMN ip TYPE inet USING ip::inet'
    end

    add_index :signins, %i[signinable_id signinable_type]
    add_index :signins, :token
  end

  def self.down
    drop_table :signins
  end
end
