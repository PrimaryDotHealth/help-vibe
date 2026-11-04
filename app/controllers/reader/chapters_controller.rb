# S02: one chapter, its sub-chapters and articles.
class Reader::ChaptersController < Reader::BaseController
  def show
    @chapter = Category.live.find_by!(slug: params[:slug])
    raise ActiveRecord::RecordNotFound unless Category.where(id: [ @chapter.id, @chapter.parent_id ].compact).where(Visibility.category_sql(viewer)).count == [ @chapter.id, @chapter.parent_id ].compact.size
    ids = [ @chapter.id ] + @chapter.children.map(&:id)
    @articles = Article.listed_for(viewer).where(main_category_id: ids).includes(:versions, :main_category).order(:code)
  end
end
