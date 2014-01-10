def sign_in_user(user, credentials)
  token = user.signin(*credentials, 'referer')
  Signin.find_by_token(token)
end

def sign_out_user(signin, credentials)
  signin.signinable.signout(signin.token, *credentials)
end
