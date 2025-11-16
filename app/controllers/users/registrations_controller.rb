class Users::RegistrationsController < Devise::RegistrationsController
  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]
  before_action :account_update_params, only: [:update]
  prepend_before_action :check_turnstile, only: [:create]

  # GET /resource/sign_up
  # def new
  #   super
  # end

  # POST /resource
  # def create
  #   super
  # end

  # GET /resource/edit
  def edit
    super
  end

  # PUT /resource
  def update
    super
  end

  def update_resource(resource, params)
    if resource.provider == 'google_oauth2'
      params.delete('current_password')
      resource.password = params['password']

      resource.update_without_password(params)
    else
      resource.update_with_password(params)
    end
  end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  # protected

  def sign_up_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation)
  end

  def account_update_params
    params.require(:user).permit(:first_name, :last_name, :email, :password, :password_confirmation, :current_password)
  end

  def check_turnstile
    token = params['cf-turnstile-response']
    
    if Rails.env.development?
      Rails.logger.debug "Turnstile token: #{token}"
    end

    unless verify_turnstile(token)
      self.resource = resource_class.new sign_up_params
      resource.validate
      set_minimum_password_length
      flash[:captcha] = "Please complete the security check!"
      render :new, status: :unprocessable_entity
    end
  end

  def verify_turnstile(token)
    return true if Rails.env.test? # Skip verification in test environment

    uri = URI('https://challenges.cloudflare.com/turnstile/v0/siteverify')
    secret_key = Rails.application.credentials.dig(Rails.env.to_sym, :cloudflare, :captcha, :secret_key)

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    # In development, skip SSL verification due to macOS certificate issues
    http.verify_mode = Rails.env.development? ? OpenSSL::SSL::VERIFY_NONE : OpenSSL::SSL::VERIFY_PEER

    http_request = Net::HTTP::Post.new(uri.path)
    http_request.set_form_data({
      secret: secret_key,
      response: token,
      remoteip: request.remote_ip
    })

    response = http.request(http_request)
    result = JSON.parse(response.body)
    result['success'] == true
  end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   flash[:notice] = 'Check your email to confirm your account'
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  def after_inactive_sign_up_path_for(resource)
    flash[:notice] = 'Check your email to confirm your account'
    super(resource)
  end
end
