# frozen_string_literal: true

module Signinable
  module ModelAdditions
    extend ActiveSupport::Concern

    module ClassMethods
      ALLOWED_RESTRICTIONS = %i[ip user_agent].freeze
      DEFAULT_REFRESH_EXP = 7200
      DEFAULT_JWT_EXP = 900

      cattr_reader :simultaneous_signings
      cattr_reader :jwt_secret
      cattr_reader :jwt_exp
      cattr_reader :refresh_exp

      def signinable(options = {})
        self.refresh_exp = options.fetch(:refresh_exp, DEFAULT_REFRESH_EXP)
        self.simultaneous_signings = options.fetch(:simultaneous, true)
        self.jwt_secret = options.fetch(:jwt_secret)
        self.jwt_exp = options.fetch(:jwt_exp, DEFAULT_JWT_EXP)

        has_many :signins, as: :signinable, dependent: :destroy

        attr_accessor :jwt
      end

      def authenticate_with_token(jwt, ip, user_agent)
        jwt_payload = extract_jwt_payload(jwt)
        return nil unless jwt_payload

        jwt = refresh_jwt(jwt_payload[:data], ip, user_agent) if jwt_payload[:expired]

        signinable = find_by(primary_key => jwt_payload[:data]['signinable_id'])
        return nil unless signinable

        signinable.jwt = jwt
        signinable
      end

      def expiration_period
        return refresh_exp.call if refresh_exp.respond_to?(:call)

        refresh_exp
      end

      def generate_jwt(refresh_token, signinable_id)
        JWT.encode(
          {
            refresh_token: refresh_token,
            signinable_id: signinable_id,
            exp: Time.zone.now.to_i + jwt_exp
          },
          jwt_secret,
          'HS256'
        )
      end

      def refresh_jwt(jwt_payload, ip, user_agent)
        old_token = jwt_payload['refresh_token']
        new_token = Signin.generate_token

        result = Signin.where(token: old_token)
                       .active
                       .update_all(
                         token: new_token,
                         expiration_time: expiration_period.seconds.from_now,
                         ip: ip,
                         user_agent: user_agent
                       )

        return if result.zero?

        generate_jwt(new_token, jwt_payload['signinable_id'])
      end

      def extract_jwt_payload(jwt)
        {
          data: JWT.decode(jwt, jwt_secret, true, { algorithm: 'HS256' })[0],
          expired: false
        }
      rescue JWT::DecodeError
        begin
          {
            data: JWT.decode(jwt, jwt_secret, true, { verify_expiration: false, algorithm: 'HS256' })[0],
            expired: true
          }
        rescue JWT::DecodeError
          nil
        end
      end

      private

      cattr_writer :refresh_exp
      cattr_writer :simultaneous_signings
      cattr_writer :jwt_secret
      cattr_writer :jwt_exp
    end

    def signin(ip, user_agent, referer, custom_data: {})
      Signin.where(signinable: self).active.map(&:expire!) unless self.class.simultaneous_signings

      signin = Signin.create!(
        signinable: self,
        ip: ip,
        referer: referer,
        user_agent: user_agent,
        expiration_time: self.class.expiration_period.seconds.from_now,
        custom_data: custom_data
      )

      self.jwt = self.class.generate_jwt(signin.token, signin.signinable_id)

      signin
    end

    def signout(jwt)
      jwt_payload = self.class.extract_jwt_payload(jwt)
      return unless jwt_payload
      return if jwt_payload[:expired]

      signin = Signin.find_by(token: jwt_payload[:data]['refresh_token'])
      return unless signin
      return if signin.expired?

      signin.expire!

      true
    end
  end
end

ActiveRecord::Base.include Signinable::ModelAdditions
