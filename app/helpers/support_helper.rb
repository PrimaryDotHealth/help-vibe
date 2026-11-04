module SupportHelper
  CODE = /\b([A-Z]{2,4})·(\d{2,3})\b/

  # Plain-text message -> safe HTML: paragraphs, links, and article codes
  # (SCH·07) linked to the article when the reader may see it.
  def render_message(part, for_contact: false, widget: false)
    viewer = for_contact ? Visibility::Viewer.anonymous : Visibility::Viewer.staff_token
    html = simple_format(h(part.body), {}, sanitize: false)
    codes = part.body.scan(CODE).map { "#{_1}·#{_2}" }.uniq
    if codes.any?
      articles = Article.where(code: codes).select { _1.visible_to?(viewer) }.index_by(&:code)
      html = html.gsub(CODE) do
        code = Regexp.last_match(0)
        (a = articles[code]) ? link_to(code, widget ? widget_article_path(a) : article_path(a), class: "code-link", target: (widget ? nil : "_blank")) : code
      end
    end
    auto_link_urls(html).html_safe
  end

  def auto_link_urls(html)
    # The text is already HTML-escaped here, so the URL can be used as-is.
    html.gsub(%r{(?<!["'>=])\bhttps?://[^\s<]+}) { |url| %(<a href="#{url}" rel="noopener nofollow" target="_blank">#{url}</a>) }
  end

  def waiting_for(thread)
    return "" unless thread.waiting_since
    distance_of_time_in_words(thread.waiting_since, Time.current).sub("about ", "").sub("less than a minute", "now")
  end

  def part_event_text(part)
    e = part.event || {}
    who = part.author_user&.first_name.presence || "System"
    case part.kind
    when "assignment" then "#{who} assigned this to #{[ e["user"], e["team"] ].compact.join(" · ").presence || "nobody"}"
    when "close" then "#{who} closed this"
    when "open" then "#{who} reopened this"
    when "snooze" then "#{who} snoozed this until #{Time.zone.parse(e["until"].to_s)&.strftime("%-d %b %H:%M")}"
    when "ticket_state_change" then e["converted"] ? "#{who} turned this into a #{e["type"]} ticket" : "#{e["reopened"] ? "Reopened by the customer's reply: " : "#{who} set the state to "}#{e["internal"]}"
    when "attribute_change" then "#{who} updated #{Array(e["changed"]).size} field(s)"
    when "link" then "#{who} opened ticket ##{e["ticket_number"]} (#{e["ticket_type"]})"
    else part.kind.humanize
    end
  end
end
