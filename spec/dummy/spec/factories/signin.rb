# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :signin do
    ip "127.0.0.1"
    signinable
  end
end
