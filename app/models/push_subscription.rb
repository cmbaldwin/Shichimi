class PushSubscription < ApplicationRecord
  belongs_to :user
  validates :endpoint, :p256dh_key, :auth_key, presence: true
end
