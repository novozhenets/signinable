# Read about factories at https://github.com/thoughtbot/factory_girl

FactoryGirl.define do
  factory :user, :aliases => [:signinable] do
    name "test"
  end
end
