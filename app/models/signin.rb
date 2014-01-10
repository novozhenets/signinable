class Signin < ActiveRecord::Base
  belongs_to :signinable, polymorphic: true

  validates :token, presence: true
  validates :ip,
            presence: true,
            format: { with: /\A([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3}\z/ }

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
