# frozen_string_literal: true

FactoryBot.define do
  factory :user, aliases: [:signinable] do
    name { 'test' }
  end
end
