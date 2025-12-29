class OfferMessagesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_offer

  def create
    authorize_message_access!
    return if performed?

    @message = @offer.messages.build(message_params)
    @message.sender = current_user

    if @message.save
      redirect_to offer_path(@offer), notice: "Message sent successfully."
    else
      redirect_to offer_path(@offer), alert: "Failed to send message: #{@message.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_offer
    @offer = Offer.find(params[:offer_id])
  end

  def message_params
    params.require(:offer_message).permit(:content)
  end

  def authorize_message_access!
    unless @offer.guest_user == current_user || @offer.host_user == current_user
      redirect_to root_path, alert: "You don't have access to this offer." and return
    end

    if current_user == @offer.host_user && @offer.messages.none?
      redirect_to offer_path(@offer), alert: "Guest must send the first message." and return
    end
  end
end
