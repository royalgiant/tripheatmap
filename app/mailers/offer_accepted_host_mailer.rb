class OfferAcceptedHostMailer < ApplicationMailer
  def notify(offer)
    @offer = offer
    @host = offer.host_user
    @guest = offer.guest_user
    @place = offer.place

    mail(
      to: @host.email,
      subject: "Your offer was accepted! - #{@place.name}"
    )
  end
end
