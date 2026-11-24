require "test_helper"

class ArticlesHelperTest < ActiveSupport::TestCase
  # Rendered through a real controller so Action Text's helpers are there.
  def body_for(html)
    article = publish_article(title: "Q and A", body: html, chapter: create_chapter)
    out = ApplicationController.render(inline: "<% h, t = article_body_with_toc(r) %><%= h %><!--TOC <%= t.map(&:last).join('|') %> -->",
                                       locals: { r: article.live_version.current_revision })
    [ Nokogiri::HTML5.fragment(out), out[/<!--TOC (.*?) -->/, 1].split("|") ]
  end

  test "questions under a Common questions heading collapse, answers kept" do
    doc, toc = body_for("<h2>Steps</h2><p>Do it.</p><h2>Common questions</h2><h3>Can I undo it?</h3><p>No.</p><h3>Who sees it?</h3><p>Only you.</p>")
    details = doc.css(".qa details")
    assert_equal 2, details.size
    assert_equal "Can I undo it?", details.first.at_css("summary span").text
    assert details.first.at_css("summary svg"), "has a chevron"
    assert_equal "No.", details.first.at_css("p").text
    assert_equal "Only you.", details.last.at_css("p").text
    assert_equal [ "Steps", "Common questions" ], toc
  end

  test "plain text separates headings from the next block" do
    assert_equal "Reschedule 1. Open Calendar. Q? No.", Revision.plain_text("<h2>Reschedule</h2><ol><li>Open Calendar.</li></ol><h3>Q?</h3><p>No.</p>")
  end
end
