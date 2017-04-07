module Signinable
  module ModelAdditions
    extend ActiveSupport::Concern

    module ClassMethods
      def signinable(options = {})
        cattr_accessor :signin_expiration
        cattr_accessor :signin_simultaneous
        cattr_accessor :signin_restrictions
        self.signin_expiration = options[:expiration] || 2.hours
        self.signin_simultaneous = options[:simultaneous] || true
        self.signin_restrictions = (options[:restrictions] && options[:restrictions].is_a?(Array)) ? options[:restrictions] : []

        has_many :signins, as: :signinable, dependent: :destroy
      end

      def authenticate_with_token(token, ip, user_agent)
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

          return nil unless self.check_signin_permission(signin, ip, user_agent)
          signin.update!(expiration_time: (Time.zone.now + self.signin_expiration)) unless self.signin_expiration == 0
          signin.signinable
        end
      end

      def check_signin_permission(signin, ip, user_agent)
        signin_permitted?(signin, ip, user_agent)
      end

      private
      def signin_permitted?(signin, ip, user_agent)
        self.signin_restrictions.each do |field|
          if(local_variables.include?(field.to_sym) && signin.respond_to?("#{field}"))
            return false unless signin.send("#{field}") == eval("#{field}")
          end
        end

        return true
      end
    end

    def signin(ip, user_agent, referer)
      expiration_time = self.class.signin_expiration == 0 ? nil : (Time.zone.now + self.class.signin_expiration)
      Signin.create!(signinable: self, ip: ip, referer: referer, user_agent: user_agent, expiration_time: expiration_time).token
    end

    def signout(token, ip, user_agent)
      if(signin = Signin.find_by_token(token))
        return nil unless self.class.check_signin_permission(signin, ip, user_agent)
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
