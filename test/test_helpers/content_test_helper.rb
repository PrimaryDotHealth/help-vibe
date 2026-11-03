module ContentTestHelper
  def create_chapter(code: "SCH", name: "Scheduling", **attrs)
    Category.create!(code: code, name: name, **attrs)
  end

  def publish_article(title:, body:, chapter:, author: users(:one), accessibility: "public", keywords: nil)
    article = Article.start!(title: title, category: chapter, author: author, accessibility: accessibility)
    article.update!(keyword_list: keywords) if keywords
    version = article.versions.first
    version.save_revision!(body: body, author: author, base_revision_id: nil)
    version.publish!(by: author)
    article
  end
end

ActiveSupport.on_load(:active_support_test_case) { include ContentTestHelper }
