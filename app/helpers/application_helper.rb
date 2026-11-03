module ApplicationHelper
  def icon(name, **opts)
    tag.svg(class: [ "i", opts.delete(:class) ].compact.join(" "), "aria-hidden": "true", **opts) do
      tag.use(href: "#i-#{name}")
    end
  end

  def code_tag(code, **opts)
    tag.span(code, class: [ "code", opts.delete(:class) ].compact.join(" "), **opts)
  end

  VISIBILITY = {
    "public"   => [ "globe", "Everyone", "Patients and the public" ],
    "internal" => [ "building", "Staff", "Anyone signed in as staff" ],
    "private"  => [ "lock", "Specific people", "Chosen people and groups" ],
    "url_only" => [ "link", "Link only", "Not listed or searchable" ]
  }.freeze

  def visibility_tag(accessibility)
    ico, label = VISIBILITY.fetch(accessibility)
    tag.span(class: "vis") { safe_join([ icon(ico), label ]) }
  end

  def relative_day(time)
    return "" unless time
    days = (Date.current - time.to_date).to_i
    case days
    when 0 then "Today"
    when 1 then "Yesterday"
    when 2..13 then "#{days} days"
    else time.strftime("%-d %b %Y")
    end
  end
end
