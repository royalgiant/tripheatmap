# Preview all emails at http://localhost:3000/rails/mailers/offer_accepted_guest_mailer
class OfferAcceptedGuestMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/offer_accepted_guest_mailer/notify
  def notify
    OfferAcceptedGuestMailer.notify
  end

end
