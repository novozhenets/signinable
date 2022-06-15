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

  describe '#expireable?' do
    it 'returns false when expireable' do
      signin = create(:signin, expiration_time: nil)
      expect(signin).to_not be_expireable
    end

    it 'returns true when expireable' do
      signin = create(:signin, expiration_time: Time.zone.now)
      expect(signin).to be_expireable
    end
  end

  describe '#expire!' do
    it 'sets expiration_time to now' do
      signin = create(:signin, expiration_time: (Time.zone.now + 1.hour))
      allow(signin).to receive(:renew!)
      signin.expire!
      expect(signin).to have_received(:renew!).with(period: 0, ip: signin.ip, user_agent: signin.user_agent)
    end
  end

  describe '#renew!' do
    let(:signin) { create(:signin) }
    let(:attrs) do
      {
        period: 100,
        ip: signin.ip,
        user_agent: signin.user_agent,
        refresh_token: false
      }
    end

    before(:each) do
      allow(signin).to receive(:update!)
    end

    it 'updates ip and user_agent' do
      signin.renew!(**attrs)
      expect(signin).to have_received(:update!).with(hash_including(ip: signin.ip, user_agent: signin.user_agent))
    end

    context 'when expireable' do
      before(:each) do
        allow(signin).to receive(:expireable?).and_return(true)
      end

      it 'updates expiration_time' do
        Timecop.freeze do
          signin.renew!(**attrs)
          expect(signin).to have_received(:update!).with(hash_including(expiration_time: Time.zone.now + attrs[:period]))
        end
      end
    end

    context 'when not expireable' do
      before(:each) do
        allow(signin).to receive(:expireable?).and_return(false)
      end

      it 'does not update expiration_time' do
        signin.renew!(**attrs)
        expect(signin).to have_received(:update!).with(hash_excluding(expiration_time: Time.zone.now + attrs[:period]))
      end
    end

    context 'when need to refresh_token' do
      it 'updates expiration_time' do
        allow(SecureRandom).to receive(:urlsafe_base64).and_return('bla')
        signin.renew!(**attrs.merge(refresh_token: true))
        expect(signin).to have_received(:update!).with(hash_including(token: 'bla'))
      end
    end

    context 'when no need to refresh_token' do
      it 'does not update expiration_time' do
        allow(SecureRandom).to receive(:urlsafe_base64).and_return('bla')
        signin.renew!(**attrs)
        expect(signin).to have_received(:update!).with(hash_excluding(token: 'bla'))
      end
    end
  end
end
