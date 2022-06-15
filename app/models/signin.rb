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
    self.token = generate_token
  end

  serialize :custom_data if ActiveRecord::Base.connection.instance_values['config'][:adapter].match('mysql')

  def expire!
    renew!(period: 0, ip: ip, user_agent: user_agent)
  end

  def expired?
    expireable? && expiration_time.past?
  end

  def expireable?
    !expiration_time.nil?
  end

  def renew!(period:, ip:, user_agent:, refresh_token: false)
    update_hash = { ip: ip, user_agent: user_agent }
    update_hash[:expiration_time] = Time.zone.now + period if expireable?
    update_hash[:token] = generate_token if refresh_token
    update!(update_hash)
  end

  private

  def generate_token
    SecureRandom.urlsafe_base64(rand(50..100))
  end
end
