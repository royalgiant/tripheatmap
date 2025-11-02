class Api::V1::ErrorLogsController < ApplicationController
  skip_before_action :verify_authenticity_token
  
  def create
    error_log = ErrorLog.log_error(
      context: params[:context],
      error_message: params.dig(:error, :message) || 'Unknown error',
      error_code: params.dig(:error, :code),
      metadata: params[:metadata] || {}
    )

    render json: { 
      success: true, 
      error_log_id: error_log.id 
    }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render json: { 
      success: false, 
      error: e.record.errors.full_messages 
    }, status: :unprocessable_entity
  rescue => e
    Rails.logger.error "Failed to log error: #{e.message}"
    render json: { 
      success: false, 
      error: 'Failed to log error' 
    }, status: :internal_server_error
  end

  private

  def error_params
    params.permit(:context, error: [:message, :code], metadata: {})
  end
end