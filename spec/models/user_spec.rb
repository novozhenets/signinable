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

  describe '.signin' do
    it 'should create Signin' do
      expect do
        sign_in_user(user, credentials)
      end.to change(Signin, :count).by(1)
    end

    it 'should set expiration_time' do
      signin = sign_in_user(user, credentials)
      expect(signin.expiration_time.to_i).to eq((Time.zone.now + User.signin_expiration).to_i)
    end

    it 'should not set expiration_time' do
      allow(User).to receive(:signin_expiration).and_return(0)
      signin = sign_in_user(user, credentials)
      expect(signin.expiration_time).to be_nil
    end
  end

  describe '.signout' do
    it 'should expire signin' do
      signin = sign_in_user(user, credentials)
      sign_out_user(signin, credentials)
      expect(signin.reload).to be_expired
    end

    context 'should be allowed with' do
      %i[ip user_agent].each do |c|
        it "changed #{c} if not restricted" do
          signin = sign_in_user(user, credentials)
          expect(sign_out_user(signin, credentials)).to be_truthy
        end
      end
    end

    context 'should not be allowed with' do
      %i[ip user_agent].each do |c|
        it "changed #{c} if restricted" do
          allow(User).to receive(:signin_restrictions).and_return([c])
          signin = sign_in_user(user, credentials)
          expect(sign_out_user(signin, other_credentials)).to be_nil
        end
      end
    end
  end

  describe '#authenticate_with_token' do
    context 'expiration_time' do
      it 'should be changed after authentication' do
        signin = sign_in_user(user, credentials)
        old_time = signin.expiration_time
        new_time = signin.expiration_time - 1.hour
        Timecop.travel(new_time)
        User.authenticate_with_token(signin.token, *credentials)
        signin.reload
        expect(signin.expiration_time.to_i).to eq((new_time + User.signin_expiration).to_i)
      end

      it 'should not be changed after authentication' do
        allow(User).to receive(:signin_expiration).and_return(0)
        signin = sign_in_user(user, credentials)
        old_time = signin.expiration_time
        Timecop.travel(Time.zone.now + 1.hour)
        User.authenticate_with_token(signin.token, *credentials)
        signin.reload
        expect(signin.expiration_time.to_i).to eq(old_time.to_i)
      end
    end

    context 'should allow signin with' do
      it 'not last token if simultaneous is permitted' do
        signin1 = sign_in_user(user, credentials)
        signin2 = sign_in_user(user, credentials)
        expect(User.authenticate_with_token(signin1.token, *credentials)).to eq(user)
        expect(User.authenticate_with_token(signin2.token, *credentials)).to eq(user)
      end

      it 'valid token' do
        signin = sign_in_user(user, credentials)
        expect(User.authenticate_with_token(signin.token, *credentials)).to eq(user)
      end

      %i[ip user_agent].each do |c|
        it "changed #{c} if not restricted" do
          signin = sign_in_user(user, credentials)
          expect(User.authenticate_with_token(signin.token, *other_credentials)).to eq(user)
        end
      end
    end

    context 'should not allow signin with' do
      it 'not last token if simultaneous not permitted' do
        allow(User).to receive(:simultaneous_signings).and_return(false)
        signin1 = sign_in_user(user, credentials)
        signin2 = sign_in_user(user, credentials)
        expect(User.authenticate_with_token(signin1.token, *credentials)).to be_nil
        expect(User.authenticate_with_token(signin2.token, *credentials)).to eq(user)
      end

      it 'expired token' do
        signin = sign_in_user(user, credentials)
        user.signout(signin.token, *credentials)
        expect(User.authenticate_with_token(signin.token, *credentials)).to be_nil
      end

      %i[ip user_agent].each do |c|
        it "changed #{c} if restricted" do
          allow(User).to receive(:signin_restrictions).and_return([c])
          signin = sign_in_user(user, credentials)
          expect(User.authenticate_with_token(signin.token, *other_credentials)).to be_nil
        end
      end
    end
  end
end
