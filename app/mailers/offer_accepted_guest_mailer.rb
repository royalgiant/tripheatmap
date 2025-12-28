class OfferAcceptedGuestMailer < ApplicationMailer
  def notify(offer)
    @offer = offer
    @guest = offer.guest_user
    @host = offer.host_user
    @place = offer.place

    mail(
      to: @guest.email,
      subject: "Offer accepted: #{@place.name}"
    )
  end
end
