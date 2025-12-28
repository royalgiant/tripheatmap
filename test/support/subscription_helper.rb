module SubscriptionHelper
  def create_active_subscription_for(user)
    Subscription.create!(
      user: user,
      status: 'active',
      current_period_end: 30.days.from_now,
      current_period_start: Time.current,
      plan_id: 'monthly_plan',
      customer_id: "cus_test_#{user.id}",
      subscription_id: "sub_test_#{user.id}"
    )
  end

  def create_expired_subscription_for(user)
    Subscription.create!(
      user: user,
      status: 'canceled',
      current_period_end: 1.day.ago,
      current_period_start: 31.days.ago,
      plan_id: 'monthly_plan',
      customer_id: "cus_test_#{user.id}",
      subscription_id: "sub_test_#{user.id}"
    )
  end
end
