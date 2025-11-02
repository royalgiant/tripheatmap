class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true

  def s3_client
		s3_client ||= Aws::S3::Client.new
  end

  def delete_from_backblaze
		delete_backblaze_object_from_url
	end

	def delete_backblaze_object_from_url
	  delete_backblaze_object(URI.parse(image_url)) if image_url.present?
	end

	def delete_backblaze_object(uri)
		bucket_name = get_bucket_name
  	object_key = uri.path.sub("/file/#{bucket_name}/", '')
	  s3_client.delete_object(bucket: get_bucket_name, key: object_key)
	rescue Aws::S3::Errors::ServiceError => e
	  # Handles errors
	  Rails.logger.error "Failed to delete object: #{e}"
	end

	def get_bucket_name
		Rails.application.credentials[Rails.env.to_sym].dig(:backblaze, :bucket_name)
	end
end
