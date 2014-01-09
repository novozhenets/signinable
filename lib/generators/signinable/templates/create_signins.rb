class CreateSignins < ActiveRecord::Migration
  def self.up
    create_table :signins do |t|
      t.integer   :signinable_id, null: false
      t.string    :signinable_type, null: false
      t.string    :token, null: false
      t.string    :referer, default: ""
      t.string    :user_agent, default: ""
      t.string    :ip, null: false
      t.datetime  :expiration_time
      t.timestamps
    end

    add_index :signins, [:signinable_id, :signinable_type]
    add_index :signins, :token
  end

  def self.down
    drop_table :signins
  end
end
