# frozen_string_literal: true

require 'resolv'

class Signin < ActiveRecord::Base
  belongs_to :signinable, polymorphic: true

  validates :token, presence: true
  validates :ip,
            presence: true,
            format: { with: Regexp.union(Resolv::IPv4::Regex, Resolv::IPv6::Regex) }

  before_validation on: :create do
    self.token = SecureRandom.urlsafe_base64(rand(50..100))
  end

  def expire!
    renew!(0)
  end

  def expired?
    expireable? && expiration_time.past?
  end

  def expireable?
    !expiration_time.nil?
  end

  def renew!(period)
    update!(expiration_time: (Time.zone.now + period))
  end

  serialize :custom_data if ActiveRecord::Base.connection.instance_values['config'][:adapter].match('mysql')
end
