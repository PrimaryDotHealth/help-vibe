module ArticlesHelper
  # Renders a revision's sanitised rich text and builds the "On this page"
  # list from its H2s (numbered sections, so "SCH·07 §2" means something).
  def article_body_with_toc(revision)
    return [ "".html_safe, [] ] unless revision&.body&.body
    html = render_action_text_content(revision.body.body)
    doc = Nokogiri::HTML5.fragment(html)
    toc = doc.css("h2").each_with_index.map do |h, i|
      h["id"] = "s#{i + 1}"
      [ h["id"], h.text.strip ]
    end
    [ doc.to_html.html_safe, toc ]
  end

  def article_link_path(article, event: nil, widget: false)
    widget ? widget_article_path(article, sid: event&.id) : article_path(article, sid: event&.id)
  end
end
