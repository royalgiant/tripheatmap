class Purchase::CheckoutsController < ApplicationController
  before_action :authenticate_user!
  def create
    price = params[:price_id] # passed in via the hidden field in pricing.html.erb
    # https://stripe.com/docs/payments/checkout/free-trials

    session_params = {
      client_reference_id: current_user.id,
      success_url: root_url + "purchase/success?session_id={CHECKOUT_SESSION_ID}",
      cancel_url: pricing_url,
      payment_method_types: ['card'],
      mode: 'subscription',
      line_items: [{
        quantity: 1,
        price: price,
      }]
    }

    # Use customer if they already have a stripe_id, otherwise use customer_email
    if current_user.stripe_id.present?
      session_params[:customer] = current_user.stripe_id
    else
      session_params[:customer_email] = current_user.email
    end

    session = Stripe::Checkout::Session.create(session_params)

    #render json: { session_id: session.id } # if you want a json response
    redirect_to session.url, allow_other_host: true
  end

  def success
    @session = Stripe::Checkout::Session.retrieve(params[:session_id])
    @customer = Stripe::Customer.retrieve(@session.customer) if @session.customer.present?
  end

  def get_payment_cancel_url(mode)
    root_url
  end
end