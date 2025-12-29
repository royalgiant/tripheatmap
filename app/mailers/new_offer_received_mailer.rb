class NewOfferReceivedMailer < ApplicationMailer
  def daily_digest(guest, offers)
    @guest = guest
    @offers = offers
    @offers_count = offers.count

    mail(
      to: @guest.email,
      subject: "You received #{@offers_count} new #{@offers_count == 1 ? 'offer' : 'offers'} for your saved searches"
    )
  end

  def weekly_digest(guest, offers)
    @guest = guest
    @offers = offers
    @offers_count = offers.count

    mail(
      to: @guest.email,
      subject: "You received #{@offers_count} new #{@offers_count == 1 ? 'offer' : 'offers'} for your saved searches"
    )
  end
end
