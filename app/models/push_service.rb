# Web Push sender (same shape as akotacos' PushService). VAPID keys come from ENV only:
# Kamal secrets in production, gitignored .env in development.
class PushService
  GONE = [ WebPush::ExpiredSubscription, WebPush::InvalidSubscription, WebPush::Unauthorized ].freeze

  class << self
    def vapid_public_key = ENV["VAPID_PUBLIC_KEY"].presence
    def vapid_private_key = ENV["VAPID_PRIVATE_KEY"].presence
    def configured? = vapid_public_key.present? && vapid_private_key.present?

    # Sends to one subscription. Returns :sent, or :gone (and destroys it) when the endpoint is dead.
    def deliver(sub, title:, body:, url: "/")
      WebPush.payload_send(
        message: { title:, body:, url: }.to_json, endpoint: sub.endpoint,
        p256dh: sub.p256dh_key, auth: sub.auth_key,
        vapid: { subject: ENV.fetch("VAPID_SUBJECT", "mailto:cody@moab.jp"), public_key: vapid_public_key, private_key: vapid_private_key }
      )
      :sent
    rescue *GONE
      sub.destroy
      :gone
    end
  end
end
