# frozen_string_literal: true

def sign_in_user(user, credentials)
  user.signin(*credentials, 'referer')
end

def sign_out_user(signin, credentials)
  signin.signinable.signout(signin.token, *credentials)
end
