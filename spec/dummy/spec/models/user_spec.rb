require File.expand_path('../../spec_helper', __FILE__)

describe User do
  before :each do
    Timecop.freeze
    User.signin_expiration = 2.hours
    User.signin_simultaneous = true
    User.signin_restrictions = []
    @user = FactoryGirl.create(:user)
    @credentials = ['127.0.0.1', 'user_agent']
    @other_credentials = ['127.0.0.2', 'user_agent2']
  end

  after :each do
    Timecop.return
  end

  describe ".signin" do
    it "should create Signin" do
      expect {
        sign_in_user(@user, @credentials)
      }.to change(Signin, :count).by(1)
    end

    it "should set expiration_time" do
      signin = sign_in_user(@user, @credentials)
      signin.expiration_time.to_i.should eq((Time.zone.now + User.signin_expiration).to_i)
    end

    it "should not set expiration_time" do
      User.signin_expiration = 0
      signin = sign_in_user(@user, @credentials)
      signin.expiration_time.should be_nil
    end
  end

  describe ".signout" do
    it "should expire signin" do
      signin = sign_in_user(@user, @credentials)
      sign_out_user(signin, @credentials)
      signin.reload
      signin.should be_expired
    end

    context "should be allowed with" do
      %w{ip user_agent}.each do |c|
        it "changed #{c} if not restricted" do
          signin = sign_in_user(@user, @credentials)
          sign_out_user(signin, @credentials).should be_true
        end
      end
    end

    context "should not be allowed with" do
      %w{ip user_agent}.each do |c|
        it "changed #{c} if restricted" do
          User.signin_restrictions = [c]
          signin = sign_in_user(@user, @credentials)
          sign_out_user(signin, @other_credentials).should be_nil
        end
      end
    end
  end

  describe "#authenticate_with_token" do
    context "expiration_time" do
      it "should be changed after authentication" do
        signin = sign_in_user(@user, @credentials)
        old_time = signin.expiration_time
        new_time = signin.expiration_time - 1.hour
        Timecop.travel(new_time)
        User.authenticate_with_token(signin.token, *@credentials)
        signin.reload
        signin.expiration_time.to_i.should eq((new_time + User.signin_expiration).to_i)
      end

      it "should not be changed after authentication" do
        User.signin_expiration = 0
        signin = sign_in_user(@user, @credentials)
        old_time = signin.expiration_time
        Timecop.travel(Time.zone.now + 1.hour)
        User.authenticate_with_token(signin.token, *@credentials)
        signin.reload
        signin.expiration_time.to_i.should eq(old_time.to_i)
      end
    end

    context "should allow signin with" do
      it "not last token if simultaneous is permitted" do
        signin1 = sign_in_user(@user, @credentials)
        signin2 = sign_in_user(@user, @credentials)
        User.authenticate_with_token(signin1.token, *@credentials).should eq(@user)
        User.authenticate_with_token(signin2.token, *@credentials).should eq(@user)
      end

      it "valid token" do
        signin = sign_in_user(@user, @credentials)
        User.authenticate_with_token(signin.token, *@credentials).should eq(@user)
      end

      %w{ip user_agent}.each do |c|
        it "changed #{c} if not restricted" do
          signin = sign_in_user(@user, @credentials)
          User.authenticate_with_token(signin.token, *@other_credentials).should eq(@user)
        end
      end
    end

    context "should not allow signin with" do
      it "not last token if simultaneous not permitted" do
        User.signin_simultaneous = false
        signin1 = sign_in_user(@user, @credentials)
        signin2 = sign_in_user(@user, @credentials)
        User.authenticate_with_token(signin1.token, *@credentials).should be_nil
        User.authenticate_with_token(signin2.token, *@credentials).should eq(@user)
      end

      it "expired token" do
        signin = sign_in_user(@user, @credentials)
        @user.signout(signin.token, *@credentials)
        User.authenticate_with_token(signin.token, *@credentials).should be_nil
      end

      %w{ip user_agent}.each do |c|
        it "changed #{c} if restricted" do
          User.signin_restrictions = [c]
          signin = sign_in_user(@user, @credentials)
          User.authenticate_with_token(signin.token, *@other_credentials).should be_nil
        end
      end
    end
  end
end
