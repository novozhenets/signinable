# frozen_string_literal: true

require 'rails_helper'

describe User do
  let(:credentials) { ['127.0.0.1', 'user_agent'] }
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
      signin =  sign_in_user(user, credentials)
      payload = JWT.decode(user.jwt, 'test', true, { algorithm: 'HS256' })[0]
      expect(payload).to include(
        'refresh_token' => signin.token,
        'signinable_id' => user.id
      )
    end

    it 'should set expiration_time' do
      signin = sign_in_user(user, credentials)
      expect(signin.expiration_time.to_i).to eq((Time.zone.now + User.refresh_exp).to_i)
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
    it 'ignores expired signin' do
      signin = sign_in_user(user, credentials)
      Timecop.travel(signin.expiration_time) do
        expect(sign_out_user(user)).to be_falsey
      end
    end

    it 'should expire signin' do
      signin = sign_in_user(user, credentials)
      sign_out_user(user)
      expect(signin.reload).to be_expired
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

      it 'returns nil if user not found' do
        allow(described_class).to receive(:find_by).and_return(nil)
        expect(described_class.authenticate_with_token(user.jwt, *credentials)).to be_nil
      end

      it 'returns user' do
        expect(described_class.authenticate_with_token(user.jwt, *credentials)).to eq(user)
      end

      it 'returns jwt with user' do
        expect(described_class.authenticate_with_token(user.jwt, *credentials).jwt).to eq(user.jwt)
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

      it 'calls for refresh token' do
        allow(described_class).to receive(:refresh_jwt)
        described_class.authenticate_with_token(user.jwt, *credentials)
        expect(described_class).to have_received(:refresh_jwt)
      end

      it 'assigns new jwt' do
        allow(User).to receive(:find_by).and_return(user)
        allow(user).to receive(:jwt=)
        described_class.authenticate_with_token(user.jwt, *credentials)
        expect(user).to have_received(:jwt=)
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
      signin = sign_in_user(user, credentials)
      Timecop.travel(Time.zone.now + described_class.refresh_exp) do
        expect(described_class.refresh_jwt(
          described_class.extract_jwt_payload(user.jwt)[:data],
          *credentials
        )).to be_nil
      end
    end

    it 'renews signin' do
      signin = sign_in_user(user, credentials)

      expect {
        described_class.refresh_jwt(
          described_class.extract_jwt_payload(user.jwt)[:data],
          *credentials
        )
        signin.reload
      }.to change { signin.token }
    end

    it 'regenerates jwt' do
      signin = sign_in_user(user, credentials)
      allow(described_class).to receive(:generate_jwt)

      described_class.refresh_jwt(
        described_class.extract_jwt_payload(user.jwt)[:data],
        *credentials
      )
      signin.reload
      expect(described_class).to have_received(:generate_jwt).with(signin.token, signin.signinable_id)
    end
  end
end
