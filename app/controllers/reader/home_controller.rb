# S01: the contents page. Each chapter with its code, its count and its most-read articles.
class Reader::HomeController < Reader::BaseController
  def show
    @chapters = Category.chapters.where(Visibility.category_sql(viewer)).to_a
    articles = Article.listed_for(viewer).includes(:versions, main_category: :parent).to_a
    @by_chapter = articles.group_by { _1.main_category.chapter.id }
    @popular = articles.sort_by { [ -_1.views, _1.code ] }.first(3)
    @chapters.select! { @by_chapter.key?(_1.id) } if collection_filter # only chapters with something to show
  end
end
