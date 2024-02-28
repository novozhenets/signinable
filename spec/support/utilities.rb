# frozen_string_literal: true

def sign_in_user(user, credentials)
  user.signin(*credentials, 'referer')
end

def sign_out_user(user)
  user.signout(user.jwt)
end
