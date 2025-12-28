# Preview all emails at http://localhost:3000/rails/mailers/new_lead_available_mailer
class NewLeadAvailableMailerPreview < ActionMailer::Preview

  # Preview this email at http://localhost:3000/rails/mailers/new_lead_available_mailer/daily_digest
  def daily_digest
    NewLeadAvailableMailer.daily_digest
  end

end
