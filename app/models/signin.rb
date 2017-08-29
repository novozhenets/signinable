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
    update_attributes(expiration_time: Time.zone.now)
  end

  def expired?
    expiration_time && expiration_time <= Time.zone.now
  end
end
