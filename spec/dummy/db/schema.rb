# frozen_string_literal: true

# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20_180_530_131_006) do
  create_table 'signins', force: :cascade do |t|
    t.integer 'signinable_id', null: false
    t.string 'signinable_type', null: false
    t.string 'token', null: false
    t.string 'referer', default: ''
    t.string 'user_agent', default: ''
    t.string 'ip', null: false
    t.datetime 'expiration_time'
    t.datetime 'created_at', null: false
    t.datetime 'updated_at', null: false
    t.string 'custom_data', default: '{}', null: false
    t.index %w[signinable_id signinable_type], name: 'index_signins_on_signinable_id_and_signinable_type'
    t.index ['token'], name: 'index_signins_on_token'
  end

  create_table 'users', force: :cascade do |t|
    t.string 'name'
  end
end
