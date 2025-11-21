class ContactMailer < ApplicationMailer
  default from: 'noreply@tripheatmap.com'

  def contact_email(email, name, subject, message)
    @email = email
    @name = name.presence || 'Anonymous'
    @subject = subject.presence || 'General Inquiry'
    @message = message

    mail(
      to: 'donald@tripheatmap.com',
      reply_to: email,
      subject: "TripHeatmap Contact: #{@subject}"
    )
  end
end