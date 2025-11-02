# app/services/auth_service.rb
class AuthService
  def s3_client
		s3_client ||= Aws::S3::Client.new
  end

  def get_bucket_name
		Rails.application.credentials[Rails.env.to_sym].dig(:backblaze, :bucket_name)
	end
end