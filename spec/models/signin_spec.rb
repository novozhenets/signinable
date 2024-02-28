# frozen_string_literal: true

require 'rails_helper'

describe Signin do
  describe '#expired?' do
    let(:expiration_time) { Time.zone.now + 1.hour }
    let(:signin) { create(:signin, expiration_time: expiration_time) }

    it 'returns false when not expired' do
      expect(signin).to_not be_expired
    end

    it 'returns true when expired' do
      Timecop.travel(expiration_time) do
        expect(signin).to be_expired
      end
    end
  end

  describe '#expire!' do
    it 'sets expiration_time to now' do
      time = Time.current
      Timecop.freeze(time) do
        signin = create(:signin, expiration_time: (Time.zone.now + 1.hour))
        allow(signin).to receive(:update!)
        signin.expire!
        expect(signin).to have_received(:update!).with(ip: signin.ip, user_agent: signin.user_agent, expiration_time: time)
      end
    end
  end
end
