module ApplicationHelper
  def is_admin_or_subscribed?
    current_user.present? && (current_user.is_admin? || current_user.subscribed?)
  end
end
