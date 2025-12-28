ENV['RAILS_ENV'] ||= 'test'
require_relative "../config/environment"
require "rails/test_help"

# Load support files
Dir[Rails.root.join('test/support/**/*.rb')].sort.each { |f| require f }

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
  fixtures :all

  # Include FactoryBot syntax methods
  include FactoryBot::Syntax::Methods

  # Include subscription helper
  include SubscriptionHelper

  # Configure default URL options for mailers
  setup do
    Rails.application.routes.default_url_options[:host] = 'www.example.com'
  end

  # Add more helper methods to be used by all tests here...
end

class ActionDispatch::IntegrationTest
  include FactoryBot::Syntax::Methods
  include SubscriptionHelper
end
