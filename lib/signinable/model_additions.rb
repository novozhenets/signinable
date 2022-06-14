# frozen_string_literal: true

module Signinable
  module ModelAdditions
    extend ActiveSupport::Concern

    module ClassMethods
      ALLOWED_RESTRICTIONS = %i[ip user_agent].freeze
      DEFAULT_EXPIRATION = 7200

      cattr_reader :signin_expiration
      cattr_reader :simultaneous_signings
      cattr_reader :signin_restrictions

      def signinable(options = {})
        self.signin_expiration = options.fetch(:expiration, DEFAULT_EXPIRATION)
        self.simultaneous_signings = options.fetch(:simultaneous, true)
        self.signin_restrictions = options[:restrictions]

        has_many :signins, as: :signinable, dependent: :destroy
      end

      def authenticate_with_token(token, ip, user_agent, skip_restrictions: [])
        signin = Signin.find_by(token: token)

        return unless signin
        return nil if signin.expired?
        return nil unless check_simultaneous_signings(signin)
        return nil unless check_signin_permission(signin, { ip: ip, user_agent: user_agent }, skip_restrictions)

        signin.renew!(expiration_period) if signin.expireable?
        signin.signinable
      end

      def check_signin_permission(signin, restrictions_to_check, skip_restrictions)
        signin_permitted?(signin, restrictions_to_check, skip_restrictions)
      end

      def expiration_period
        return signin_expiration.call if signin_expiration.respond_to?(:call)

        signin_expiration
      end

      private

      cattr_writer :signin_expiration
      cattr_writer :simultaneous_signings
      cattr_writer :signin_restrictions

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

      def check_simultaneous_signings(signin)
        return true if simultaneous_signings

        signin == signin.signinable.last_signin
      end
    end

    def signin(ip, user_agent, referer, permanent: false, custom_data: {})
      expires_in = self.class.expiration_period
      expiration_time = expires_in.zero? || permanent ? nil : expires_in.seconds.from_now
      Signin.create!(
        signinable: self,
        ip: ip,
        referer: referer,
        user_agent: user_agent,
        expiration_time: expiration_time,
        custom_data: custom_data
      ).token
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
      signins.last
    end
  end
end

ActiveRecord::Base.include Signinable::ModelAdditions
