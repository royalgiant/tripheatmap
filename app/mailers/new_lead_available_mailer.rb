class NewLeadAvailableMailer < ApplicationMailer
  def daily_digest(host, saved_searches)
    @host = host
    @saved_searches = saved_searches
    @leads_count = saved_searches.count

    mail(
      to: @host.email,
      subject: "#{@leads_count} new #{@leads_count == 1 ? 'traveler is' : 'travelers are'} looking in your area"
    )
  end

  def weekly_digest(host, saved_searches)
    @host = host
    @saved_searches = saved_searches
    @leads_count = saved_searches.count

    mail(
      to: @host.email,
      subject: "#{@leads_count} new #{@leads_count == 1 ? 'traveler is' : 'travelers are'} looking in your area"
    )
  end
end
