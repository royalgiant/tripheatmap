# Preview all emails at http://localhost:3000/rails/mailers/offer_accepted_host_mailer
class OfferAcceptedHostMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/offer_accepted_host_mailer/notify
  def notify
    OfferAcceptedHostMailer.notify
  end

end
