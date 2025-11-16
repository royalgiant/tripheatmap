class Users::ConfirmationsController < Devise::ConfirmationsController
  # GET /resource/confirmation/new
  def new
    super
  end

  # POST /resource/confirmation
  def create
    self.resource = resource_class.send_confirmation_instructions(resource_params)
    yield resource if block_given?

    if successfully_sent?(resource)
      flash[:success] = "Your confirmation email has been sent. Please check your email."
      redirect_to after_resending_confirmation_instructions_path_for(resource_name)
    else
      flash[:error] = "Email not found"
      render :new
    end
  end

  # GET /resource/confirmation?confirmation_token=abcdef
  def show
    super do |resource|
      if resource.errors.empty?
        sign_in(resource) # Sign in the user
        flash[:sucess] = "Your email has been confirmed."
        redirect_to after_confirmation_path_for(resource_name, resource) and return
      end
    end
  end

  # protected

  # The path used after resending confirmation instructions.
  def after_resending_confirmation_instructions_path_for(resource_name)
    super(resource_name)
  end

  # The path used after confirmation.
  def after_confirmation_path_for(resource_name, resource)
    root_path
  end
end
