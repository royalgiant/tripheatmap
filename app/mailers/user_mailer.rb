class UserMailer < ApplicationMailer
  def shopify_welcome
    @user = params[:user]
    @login_url = new_user_session_url
    
    mail(
      to: @user.email,
      subject: 'Welcome to TripHeatMap - Your Account Details'
    )
  end

  def shopify_password
    @user = params[:user]
    @temp_password = params[:temp_password]
    
    mail(
      to: @user.email,
      subject: 'TripHeatMap - Your Temporary Password'
    )
  end
end