# frozen_string_literal: true

require 'resolv'

class Signin < ActiveRecord::Base
  belongs_to :signinable, polymorphic: true

  validates :token, presence: true
  validates :ip,
            presence: true,
            format: { with: Regexp.union(Resolv::IPv4::Regex, Resolv::IPv6::Regex) }

  scope :active, -> { where('expiration_time IS NULL OR expiration_time > ?', Time.zone.now) }

  before_validation on: :create do
    self.token = self.class.generate_token
  end

  serialize :custom_data if ActiveRecord::Base.connection.instance_values['config'][:adapter].match('mysql')

  def expire!
    update!(
      ip: ip,
      user_agent: user_agent,
      expiration_time: Time.current
    )
  end

  def expired?
    expiration_time.past?
  end

  def self.generate_token
    SecureRandom.urlsafe_base64(rand(50..100))
  end
end
