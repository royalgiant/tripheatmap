module OffersHelper
  def offer_status_badge_classes(status, on_blue_header: false)
    case status
    when 'accepted'
      'bg-green-100 text-green-800'
    when 'declined'
      'bg-red-100 text-red-800'
    when 'expired'
      'bg-gray-100 text-gray-800'
    else # 'sent', 'viewed', or any other active status
      on_blue_header ? 'bg-white text-blue-700' : 'bg-blue-100 text-blue-800'
    end
  end
end
