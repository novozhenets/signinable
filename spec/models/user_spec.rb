# frozen_string_literal: true

require 'rails_helper'

describe User do
  let(:credentials) { ['127.0.0.1', 'user_agent'] }
  let(:other_credentials) { ['127.0.0.2', 'user_agent2'] }
  let(:user) { create(:user) }

  before :each do
    Timecop.freeze
  end

  after :each do
    Timecop.return
  end

  describe '#signin' do
    it 'should create Signin' do
      expect do
        sign_in_user(user, credentials)
      end.to change(Signin, :count).by(1)
    end

    it 'sets jwt on user instance' do
      expect do
        sign_in_user(user, credentials)
      end.to change(user, :jwt).from(nil)
    end

    it 'should generate jwt with correct payload' do
      sign_in_user(user, credentials)
      signin = user.last_signin
      payload = JWT.decode(user.jwt, 'test', true, { algorithm: 'HS256' })[0]
      expect(payload).to include(
        'refresh_token' => signin.token,
        'signinable_id' => user.id
      )
    end

    it 'should set expiration_time' do
      sign_in_user(user, credentials)
      signin = user.last_signin
      expect(signin.expiration_time.to_i).to eq((Time.zone.now + User.refresh_exp).to_i)
    end

    it 'should not set expiration_time' do
      allow(described_class).to receive(:refresh_exp).and_return(0)
      sign_in_user(user, credentials)
      signin = user.last_signin
      expect(signin.expiration_time).to be_nil
    end

    context 'when simultaneous signins enabled' do
      before do
        allow(described_class).to receive(:simultaneous_signings).and_return(true)
      end

      it 'does not expire active signins' do
        sign_in_user(user, credentials)
        sign_in_user(user, credentials)
        expect(user.signins.active.count).to eq(2)
      end
    end

    context 'when simultaneous signins disabled' do
      before do
        allow(described_class).to receive(:simultaneous_signings).and_return(false)
      end

      it 'expires active signins' do
        sign_in_user(user, credentials)
        sign_in_user(user, credentials)
        expect(user.signins.active.count).to eq(1)
      end
    end
  end

  describe '#signout' do
    it 'should expire signin' do
      sign_in_user(user, credentials)
      signin = user.last_signin
      sign_out_user(signin, credentials)
      expect(signin.reload).to be_expired
    end

    context 'when has no restrictions' do
      %i[ip user_agent].each do |c|
        it "allows signout when #{c} changes" do
          sign_in_user(user, credentials)
          signin = user.last_signin
          expect(sign_out_user(signin, credentials)).to be_truthy
        end
      end
    end

    context 'when has restrictions' do
      %i[ip user_agent].each do |c|
        it "forbids signout when #{c} changes" do
          allow(described_class).to receive(:signin_restrictions).and_return([c])
          sign_in_user(user, credentials)
          signin = user.last_signin
          expect(sign_out_user(signin, other_credentials)).to be_nil
        end
      end
    end
  end

  describe '#last_signin' do
    it 'retuns nil when no signins' do
      expect(user.last_signin).to be_nil
    end

    it 'returns last active signin' do
      sign_in_user(user, credentials)
      sign_in_user(user, credentials)
      signin = user.signins.active.last
      sign_in_user(user, credentials)
      user.signins.last.expire!

      expect(user.last_signin).to eq(signin)
    end
  end

  describe '.generate_jwt' do
    let(:token) { SecureRandom.urlsafe_base64(rand(50..100)) }

    it 'sets correct payload' do
      jwt = described_class.generate_jwt(token, user.id)
      payload = JWT.decode(jwt, described_class.jwt_secret, true, { algorithm: 'HS256' })[0]
      expect(payload).to eq(
        'refresh_token' => token,
        'signinable_id' => user.id,
        'exp' => Time.zone.now.to_i + described_class.jwt_exp
      )
    end
  end

  describe '.authenticate_with_token' do
    context 'when jwt is invalid' do
      it 'returns nil' do
        expect(described_class.authenticate_with_token('blablabla', *credentials)).to be_nil
      end
    end

    context 'when jwt has not expired' do
      before(:each) do
        sign_in_user(user, credentials)
      end

      it 'returns user' do
        expect(described_class.authenticate_with_token(user.jwt, *credentials)).to eq(user)
      end

      it 'does not update refresh token' do
        allow(described_class).to receive(:refresh_jwt)
        described_class.authenticate_with_token(user.jwt, *credentials)
        expect(described_class).not_to have_received(:refresh_jwt)
      end
    end

    context 'when jwt has expired' do
      before(:each) do
        sign_in_user(user, credentials)
        Timecop.travel(Time.zone.now + described_class.jwt_exp)
      end

      it 'does not do user lookup' do
        allow(described_class).to receive(:find_by)
        described_class.authenticate_with_token(user.jwt, *credentials)
        expect(described_class).not_to have_received(:find_by)
      end

      it 'calls for refresh token' do
        allow(described_class).to receive(:refresh_jwt)
        described_class.authenticate_with_token(user.jwt, *credentials)
        expect(described_class).to have_received(:refresh_jwt)
      end
    end
  end

  describe '.refresh_jwt' do
    context 'when jwt is invalid' do
      it 'returns nil' do
        expect(described_class.refresh_jwt('blablabla', *credentials)).to be_nil
      end
    end

    it 'returns nil when signin not found' do
      jwt = described_class.generate_jwt('blablabla', 0)
      expect(described_class.refresh_jwt(jwt, *credentials)).to be_nil
    end

    it 'returns nil when signin expired' do
      sign_in_user(user, credentials)
      signin = user.last_signin
      Timecop.travel(Time.zone.now + described_class.refresh_exp)
      expect(described_class.refresh_jwt(user.jwt, *credentials)).to be_nil
    end

    context 'when has no restrictions' do
      %i[ip user_agent].each do |c|
        it "allows signin when #{c} changed" do
          sign_in_user(user, credentials)
          expect(described_class.refresh_jwt(user.jwt, *other_credentials)).to eq(user)
        end
      end
    end

    context 'when has restrictions' do
      %i[ip user_agent].each do |c|
        it "forbids signin when #{c} changed" do
          allow(User).to receive(:signin_restrictions).and_return([c])
          sign_in_user(user, credentials)
          expect(described_class.refresh_jwt(user.jwt, *other_credentials)).to be_nil
        end
      end
    end

    it 'renews signin' do
      sign_in_user(user, credentials)
      signin = user.last_signin
      allow(signin).to receive(:renew!)
      allow(Signin).to receive(:find_by).with(token: signin.token).and_return(signin)

      described_class.refresh_jwt(user.jwt, *credentials)
      expect(signin).to have_received(:renew!).with(period: described_class.expiration_period, ip: credentials[0],
                                                    user_agent: credentials[1], refresh_token: true)
    end

    it 'assigns new jwt' do
      sign_in_user(user, credentials)
      signin = user.last_signin
      allow(user).to receive(:jwt=)
      allow(signin).to receive(:signinable).and_return(user)
      allow(Signin).to receive(:find_by).with(token: signin.token).and_return(signin)
      allow(described_class).to receive(:generate_jwt).and_return('bla')

      described_class.refresh_jwt(user.jwt, *credentials)
      expect(user).to have_received(:jwt=).with('bla')
    end

    it 'regenerates jwt' do
      sign_in_user(user, credentials)
      signin = user.last_signin
      allow(described_class).to receive(:generate_jwt)

      described_class.refresh_jwt(user.jwt, *credentials)
      signin.reload
      expect(described_class).to have_received(:generate_jwt).with(signin.token, signin.signinable_id)
    end
  end
end
