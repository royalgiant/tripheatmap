class StaticController < ApplicationController
  def terms
  end

  def privacy
  end

  def about
  end

  def deals
  end

  def tripheatmap_how_to
  end

  def landing
  end

  def contact
    if request.post?
      contact_params = params.permit(:email, :name, :subject, :message)

      # Validate required fields
      if contact_params[:email].blank? || contact_params[:message].blank?
        flash[:alert] = "Email and message are required."
        redirect_to contact_path and return
      end

      # Validate email format
      unless contact_params[:email].match?(/\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i)
        flash[:alert] = "Please provide a valid email address."
        redirect_to contact_path and return
      end

      # Validate input lengths
      if contact_params[:message].length > 5000
        flash[:alert] = "Message is too long (maximum 5000 characters)."
        redirect_to contact_path and return
      end

      if contact_params[:name].to_s.length > 100 || contact_params[:subject].to_s.length > 200
        flash[:alert] = "Name or subject is too long."
        redirect_to contact_path and return
      end

      if seo_spam_detected?(contact_params)
        flash[:alert] = "Your message appears to be spam and was not sent."
        redirect_to contact_path and return
      end

      if contact_params[:name].to_s.match?(/https?:\/\//) ||
         contact_params[:subject].to_s.match?(/https?:\/\/|\.com|www\./i) ||
         contact_params[:message].to_s.match?(/https?:\/\/|\.com|www\./i)
        flash[:alert] = "Invalid input detected. URLs and web addresses are not allowed in contact form submissions."
        redirect_to contact_path and return
      end

      ContactMailer.contact_email(
        contact_params[:email],
        contact_params[:name],
        contact_params[:subject],
        contact_params[:message]
      ).deliver_now

      redirect_to contact_path, flash: { success: "Message sent! We'll respond within 24 hours." }
    end
  end

  private

  def seo_spam_detected?(contact_params)
    combined_text = [
      contact_params[:name],
      contact_params[:subject],
      contact_params[:message]
    ].compact.join(" ").downcase

    seo_spam_terms = [
      /ranking.*(?:high|top|first|1st).*(?:google|search engine|yahoo|bing)/i,
      /(?:google|search engine).*(?:first|1st).*page/i,
      /top.*ranking.*(?:google|search)/i,
      /rank.*higher.*(?:google|search)/i,
      /seo.*(?:company|service|expert|agency|specialist)/i,
      /increase.*(?:leads|traffic|revenue|sales|clients)/i,
      /improve.*(?:website|seo|ranking|visibility)/i,
      /boost.*(?:ranking|traffic|seo|visibility)/i,
      /organic.*traffic/i,
      /google.*yahoo.*bing/i,
      /search.*engine.*optimization/i,
      /website.*not.*ranking/i,
      /place.*website.*(?:google|first page)/i,
      /digital.*marketing.*(?:service|agency|company)/i,
      /backlinks|link.*building/i,
      /interested\?.*provide.*(?:name|contact|email)/i,
      /get.*more.*(?:traffic|leads|customers)/i,
      /want.*more.*(?:business|sales|clients)/i,
      /(?:accounts|business|sales).*manager.*(?:seo|marketing|digital)/i,
    ]

    seo_spam_terms.any? { |pattern| combined_text.match?(pattern) }
  end
end