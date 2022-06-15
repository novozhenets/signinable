# frozen_string_literal: true

class User < ActiveRecord::Base
  signinable jwt_secret: 'test', jwt_exp: 100
end
