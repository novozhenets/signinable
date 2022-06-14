# frozen_string_literal: true

require 'rails_helper'

describe Signin do
  it 'has a valid factory' do
    signin = build(:signin)
    expect(signin).to be_valid
  end

  context 'is invalid without' do
    it 'a token' do
      signin = create(:signin)
      signin.token = nil
      expect(signin).to_not be_valid
    end

    it 'an ip' do
      expect(build(:signin, ip: nil)).to_not be_valid
    end
  end

  it 'should generate token on create' do
    signin = create(:signin, token: nil)
    expect(signin.token).to_not be_nil
  end

  context 'not valid with' do
    it 'wrong ip' do
      expect(build(:signin, ip: '123')).to_not be_valid
    end
  end

  it 'should expire' do
    Timecop.freeze
    expiration_time = Time.zone.now + 1.hour
    signin = create(:signin, expiration_time: expiration_time)
    Timecop.travel(expiration_time)
    expect(signin).to be_expired
    Timecop.return
  end

  describe '.expire!' do
    it 'should set expiration_time to now' do
      Timecop.freeze
      signin = create(:signin, expiration_time: (Time.zone.now + 1.hour))
      signin.expire!
      expect(signin).to be_expired
      Timecop.return
    end
  end
end
