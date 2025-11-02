class ContactMailer < ApplicationMailer
  default from: 'noreply@yourdomain.com'

  def contact_email(email, message)
    @email = email
    @message = message
    
    mail(
      to: 'support@yourdomain.com',
      subject: 'Contact Form Submission'
    )
  end
end