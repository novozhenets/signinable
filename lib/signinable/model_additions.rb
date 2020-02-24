module Signinable
  module ModelAdditions
    extend ActiveSupport::Concern

    module ClassMethods
      def signinable(options = {})
        cattr_accessor :signin_expiration
        cattr_accessor :signin_simultaneous
        cattr_accessor :signin_restrictions
        self.signin_expiration = options.fetch(:expiration, 2.hours)
        self.signin_simultaneous = options.fetch(:simultaneous, true)
        self.signin_restrictions = options[:restrictions]

        has_many :signins, as: :signinable, dependent: :destroy
      end

      def authenticate_with_token(token, ip, user_agent, skip_restrictions=[])
        if(signin = Signin.find_by_token(token))
          if self.signin_expiration.respond_to?(:call)
            self.signin_expiration = self.signin_expiration.call(signin.signinable)
          end

          if self.signin_expiration > 0
            return nil if signin.expired?
          end

          unless self.signin_simultaneous
            return nil unless signin == signin.signinable.last_signin
          end

          return nil unless self.check_signin_permission(signin, ip, user_agent, skip_restrictions)
          signin.update!(expiration_time: (Time.zone.now + self.signin_expiration)) unless signin.expiration_time.nil? || self.signin_expiration == 0
          signin.signinable
        end
      end

      def check_signin_permission(signin, ip, user_agent, skip_restrictions)
        signin_permitted?(signin, ip, user_agent, skip_restrictions)
      end

      private
      def signin_permitted?(signin, ip, user_agent, skip_restrictions)
        restriction_fields = case
        when self.signin_restrictions.respond_to?(:call)
          self.signin_restrictions.call(signin.signinable)
        when self.signin_restrictions.is_a?(Array)
          self.signin_restrictions
        else
          []
        end

        (restriction_fields - skip_restrictions).each do |field|
          if(local_variables.include?(field.to_sym) && signin.respond_to?("#{field}"))
            return false unless signin.send("#{field}") == eval("#{field}")
          end
        end

        return true
      end
    end

    def signin(ip, user_agent, referer, permanent = false, custom_data = {})
      if self.class.signin_expiration.respond_to?(:call)
        self.class.signin_expiration = self.class.signin_expiration.call(self)
      end
      expiration_time = (self.class.signin_expiration == 0 || permanent) ? nil : (Time.zone.now + self.class.signin_expiration)
      Signin.create!(custom_data: custom_data, signinable: self, ip: ip, referer: referer, user_agent: user_agent, expiration_time: expiration_time).token
    end

    def signout(token, ip, user_agent, skip_restrictions=[])
      if(signin = Signin.find_by_token(token))
        return nil unless self.class.check_signin_permission(signin, ip, user_agent, skip_restrictions)
        signin.expire!

        return true
      end

      return nil
    end

    def last_signin
      signins.last unless signins.empty?
    end
  end
end

ActiveRecord::Base.send(:include, Signinable::ModelAdditions)
