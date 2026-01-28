class ContactMailer < ApplicationMailer
  default from: 'noreply@tripheatmap.com'

  def contact_email(email, name, subject, message)
    @email = sanitize_email(email)
    @name = sanitize_text(name.presence || 'Anonymous')
    @subject = sanitize_text(subject.presence || 'General Inquiry')
    @message = sanitize_text(message)

    mail(
      to: 'donald@tripheatmap.com',
      reply_to: @email,
      subject: "TripHeatmap Contact: #{@subject}"
    )
  end

  private

  def sanitize_email(email)
    email.to_s.gsub(/[\r\n]/, '')
  end

  def sanitize_text(text)
    text.to_s.gsub(/[\r\n]/, ' ').strip.truncate(1000)
  end
end