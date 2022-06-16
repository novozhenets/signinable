# frozen_string_literal: true

module Signinable
  module ModelAdditions
    extend ActiveSupport::Concern

    module ClassMethods
      ALLOWED_RESTRICTIONS = %i[ip user_agent].freeze
      DEFAULT_REFRESH_EXP = 7200
      DEFAULT_JWT_EXP = 900

      cattr_reader :refresh_exp
      cattr_reader :simultaneous_signings
      cattr_reader :signin_restrictions
      cattr_reader :jwt_secret
      cattr_reader :jwt_exp

      def signinable(options = {})
        self.refresh_exp = options.fetch(:expiration, DEFAULT_REFRESH_EXP)
        self.simultaneous_signings = options.fetch(:simultaneous, true)
        self.signin_restrictions = options[:restrictions]
        self.jwt_secret = options.fetch(:jwt_secret)
        self.jwt_exp = options.fetch(:jwt_exp, DEFAULT_JWT_EXP)

        has_many :signins, as: :signinable, dependent: :destroy

        attr_accessor :jwt
      end

      def authenticate_with_token(jwt, ip, user_agent, skip_restrictions: [])
        jwt_payload = extract_jwt_payload(jwt)
        return refresh_jwt(jwt, ip, user_agent, skip_restrictions: skip_restrictions) unless jwt_payload

        signinable = find_by(primary_key => jwt_payload['signinable_id'])
        return nil unless signinable

        signinable.jwt = jwt
        signinable
      end

      def check_signin_permission(signin, restrictions_to_check, skip_restrictions)
        signin_permitted?(signin, restrictions_to_check, skip_restrictions)
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

      def refresh_jwt(jwt, ip, user_agent, skip_restrictions: [])
        token = refresh_token_from_jwt(jwt)
        return nil unless token

        signin = Signin.find_by(token: token)

        return unless signin
        return nil if signin.expired?
        return nil unless check_signin_permission(signin, { ip: ip, user_agent: user_agent }, skip_restrictions)

        signin.renew!(period: expiration_period, ip: ip, user_agent: user_agent, refresh_token: true)
        signin.signinable.jwt = generate_jwt(signin.token, signin.signinable_id)
        signin.signinable
      end

      private

      cattr_writer :refresh_exp
      cattr_writer :simultaneous_signings
      cattr_writer :signin_restrictions
      cattr_writer :jwt_secret
      cattr_writer :jwt_exp

      def extract_jwt_payload(jwt)
        JWT.decode(jwt, jwt_secret, true, { algorithm: 'HS256' })[0]
      rescue JWT::DecodeError
        nil
      end

      def refresh_token_from_jwt(jwt)
        JWT.decode(jwt, jwt_secret, true, { verify_expiration: false, algorithm: 'HS256' })[0]['refresh_token']
      rescue JWT::DecodeError
        nil
      end

      def signin_permitted?(signin, restrictions_to_check, skip_restrictions)
        restriction_fields = signin_restriction_fields(signin, skip_restrictions)

        restrictions_to_check.slice(*restriction_fields).each do |field, value|
          return false unless signin.send(field) == value
        end

        true
      end

      def signin_restriction_fields(signin, skip_restrictions)
        fields = if signin_restrictions.respond_to?(:call)
                   signin_restrictions.call(signin.signinable)
                 elsif signin_restrictions.is_a?(Array)
                   signin_restrictions
                 else
                   []
                 end
        (fields - skip_restrictions) & ALLOWED_RESTRICTIONS
      end
    end

    def signin(ip, user_agent, referer, permanent: false, custom_data: {})
      expires_in = self.class.expiration_period
      expiration_time = expires_in.zero? || permanent ? nil : expires_in.seconds.from_now
      Signin.where(signinable: self).active.map(&:expire!) unless self.class.simultaneous_signings
      signin = Signin.create!(
        signinable: self,
        ip: ip,
        referer: referer,
        user_agent: user_agent,
        expiration_time: expiration_time,
        custom_data: custom_data
      )

      self.jwt = self.class.generate_jwt(signin.token, signin.signinable_id)
    end

    def signout(token, ip, user_agent, skip_restrictions: [])
      signin = Signin.find_by_token(token)

      return unless signin
      return unless self.class.check_signin_permission(
        signin,
        { ip: ip, user_agent: user_agent },
        skip_restrictions
      )

      signin.expire!

      true
    end

    def last_signin
      signins.active.last
    end
  end
end

ActiveRecord::Base.include Signinable::ModelAdditions
