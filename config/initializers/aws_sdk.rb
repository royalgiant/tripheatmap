# config/initializers/aws_sdk.rb
backblaze_key_id = ENV["BACKBLAZE_KEY_ID"] || Rails.application.credentials[Rails.env.to_sym]&.dig(:backblaze, :keyID)
backblaze_app_key = ENV["BACKBLAZE_APP_KEY"] || Rails.application.credentials[Rails.env.to_sym]&.dig(:backblaze, :applicationKey)
Rails.logger.info("Key ID #{backblaze_key_id} and App Key #{backblaze_app_key}")
Aws.config.update({
  region: 'us-east-005', # Placeholder region, as Backblaze B2 does not use AWS-style regions
  credentials: Aws::Credentials.new(backblaze_key_id, backblaze_app_key),
  endpoint: 'https://s3.us-east-005.backblazeb2.com', # Adjust as necessary for your B2 bucket endpoint
  force_path_style: true,
  http_wire_trace: Rails.env.development?, # Enable HTTP wire traces in development for debugging
  compute_checksums: false, # Disable checksum computation to avoid sending headers like x-amz-checksum-crc32
  request_checksum_calculation: "never", # Explicitly disable request checksums
  response_checksum_validation: "never" # Explicitly disable response checksum validation
})