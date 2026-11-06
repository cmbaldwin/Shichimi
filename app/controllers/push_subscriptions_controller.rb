class PushSubscriptionsController < ApplicationController
  # POST /push_subscriptions  { subscription: { endpoint:, keys: { p256dh:, auth: } } }
  def create
    sub = params.expect(subscription: [ :endpoint, { keys: %i[p256dh auth] } ])
    record = PushSubscription.find_or_initialize_by(endpoint: sub[:endpoint])
    return head :forbidden if record.persisted? && record.user_id != current_user.id # endpoint owned by someone else

    record.update!(user: current_user, p256dh_key: sub.dig(:keys, :p256dh), auth_key: sub.dig(:keys, :auth))
    head :created
  end

  # DELETE /push_subscriptions  { endpoint: }
  def destroy
    current_user.push_subscriptions.where(endpoint: params[:endpoint]).destroy_all
    head :no_content
  end

  # POST /push_subscriptions/test: pushes to this user's devices
  def test
    sent = current_user.push_subscriptions.map { PushService.deliver(it, title: "Shichimi", body: "Test notification: reminders work.") }
    render json: { sent: sent.count(:sent) }
  end
end
