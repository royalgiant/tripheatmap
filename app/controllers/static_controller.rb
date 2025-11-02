class StaticController < ApplicationController
  def terms
  end

  def privacy
  end

  def tripheatmap_how_to
  end

  def landing
  end

  def contact
    if request.post?
      email = params[:email]
      message = params[:message]
      
      ContactMailer.contact_email(email, message).deliver_now
    
      flash[:success] = "Your message has been sent. We'll get back to you as soon as possible!"
      redirect_to contact_path
    end
  end
end