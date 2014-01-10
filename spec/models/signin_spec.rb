require 'spec_helper'

describe Signin do
  it "has a valid factory" do
    signin = FactoryGirl.build(:signin)
    signin.should be_valid
  end

  context "is invalid without" do
    it "a token" do
      signin = FactoryGirl.create(:signin)
      signin.token = nil
      signin.should_not be_valid
    end

    it "an ip" do
      FactoryGirl.build(:signin, ip: nil).should_not be_valid
    end
  end

  it "should generate token on create" do
    signin = FactoryGirl.create(:signin, token: nil)
    signin.token.should_not be_nil
  end

  context "not valid with" do
    it "wrong ip" do
      FactoryGirl.build(:signin, ip: "123").should_not be_valid
    end
  end

  it "should expire" do
    Timecop.freeze
    expiration_time = Time.zone.now + 1.hour
    signin = FactoryGirl.create(:signin, expiration_time: expiration_time)
    Timecop.travel(expiration_time)
    signin.should be_expired
    Timecop.return
  end

  describe ".expire!" do
    it "should set expiration_time to now" do
      Timecop.freeze
      signin = FactoryGirl.create(:signin, expiration_time: (Time.zone.now + 1.hour))
      signin.expire!
      signin.should be_expired
      Timecop.return
    end
  end
end
