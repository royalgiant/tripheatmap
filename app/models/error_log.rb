class ErrorLog < ApplicationRecord
  validates :context, presence: true
  validates :error_message, presence: true

  def self.log_error(context:, error_message:, error_code: nil, metadata: {})
    create!(
      context: context,
      error_message: error_message,
      error_code: error_code,
      metadata: metadata
    )
  end
end