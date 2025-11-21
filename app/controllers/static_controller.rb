class StaticController < ApplicationController
  def terms
  end

  def privacy
  end

  def about
  end

  def tripheatmap_how_to
  end

  def landing
  end

  def contact
    if request.post?
      email = params[:email]
      name = params[:name]
      subject = params[:subject]
      message = params[:message]

      # Validate required fields
      if email.blank? || message.blank?
        flash[:error] = "Email and message are required."
        redirect_to contact_path and return
      end

      ContactMailer.contact_email(email, name, subject, message).deliver_now
      redirect_to contact_path, flash: { success: "Your message has been sent. We'll get back to you as soon as possible!" }
    end
  end
end