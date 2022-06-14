# frozen_string_literal: true

FactoryBot.define do
  factory :signin do
    ip { '127.0.0.1' }
    signinable
  end
end
