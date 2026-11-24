module ArticlesHelper
  CALLOUT = /\A\s*(Note|Tip|Info|Caution|Warning|Important)\s*[:—-]\s*/i
  QA_HEADING = /\A\s*(common questions|questions|faqs?|frequently asked questions)\s*\z/i

  # Renders a revision's sanitised rich text, then applies the house
  # conventions (no custom editor plugins needed):
  #   * a quote starting "Note:", "Tip:", "Caution:", "Warning:" -> a callout
  #   * under an H2 called "Common questions"/"FAQ", each H3 and what follows
  #     it -> a collapsible question
  # and builds the "On this page" list from the H2s.
  def article_body_with_toc(revision)
    return [ "".html_safe, [] ] unless revision&.body&.body
    doc = Nokogiri::HTML5.fragment(render_action_text_content(revision.body.body))
    callouts!(doc)
    questions!(doc)
    toc = doc.css("h2").each_with_index.map do |h, i|
      h["id"] = "s#{i + 1}"
      [ h["id"], h.text.strip ]
    end
    [ doc.to_html.html_safe, toc ]
  end

  def article_link_path(article, event: nil, widget: false)
    widget ? widget_article_path(article, sid: event&.id) : article_path(article, sid: event&.id)
  end

  private
    def callouts!(doc)
      doc.css("blockquote").each do |quote|
        first_text = quote.xpath(".//text()").find { _1.text.strip.present? }
        next unless first_text && (m = first_text.text.match(CALLOUT))
        kind = m[1].downcase
        first_text.content = first_text.text.sub(CALLOUT, "")
        caution = %w[caution warning important].include?(kind)
        note = Nokogiri::XML::Node.new("div", doc.document)
        note["class"] = caution ? "note caution" : "note"
        label = Nokogiri::XML::Node.new("div", doc.document)
        label["class"] = "label"
        label.content = m[1].capitalize
        body = Nokogiri::XML::Node.new("div", doc.document)
        body.inner_html = quote.inner_html
        note.add_child(label)
        note.add_child(body)
        quote.replace(note)
      end
    end

    def questions!(doc)
      doc.css("h2").each do |h2|
        next unless h2.text.match?(QA_HEADING)
        node = h2.next_sibling
        qa = Nokogiri::XML::Node.new("div", doc.document)
        qa["class"] = "qa"
        current = nil
        while node && node.name != "h2"
          following = node.next_sibling
          if node.name == "h3"
            current = Nokogiri::XML::Node.new("details", doc.document)
            summary = Nokogiri::XML::Node.new("summary", doc.document)
            summary.inner_html = "<span>#{node.inner_html}</span>"
            summary.add_child(Nokogiri::HTML5.fragment(icon("down")))
            current.add_child(summary)
            qa.add_child(current)
            node.remove
          elsif current
            current.add_child(node.unlink)
          end
          node = following
        end
        h2.add_next_sibling(qa) if qa.children.any?
      end
    end
end
