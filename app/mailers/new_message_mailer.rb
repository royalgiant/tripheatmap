class NewMessageMailer < ApplicationMailer
  def notify(message)
    @message = message
    @offer = message.offer

    # Determine recipient (opposite of sender)
    @recipient = if message.from_host?
      @offer.guest_user
    else
      @offer.host_user
    end

    @sender_name = message.from_host? ? @offer.place.name : "Guest"

    mail(
      to: @recipient.email,
      subject: "New message from #{@sender_name}"
    )
  end
end
