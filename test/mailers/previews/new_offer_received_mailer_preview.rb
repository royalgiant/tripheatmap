# Preview all emails at http://localhost:3000/rails/mailers/new_offer_received_mailer
class NewOfferReceivedMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/new_offer_received_mailer/daily_digest
  def daily_digest
    NewOfferReceivedMailer.daily_digest
  end

end
