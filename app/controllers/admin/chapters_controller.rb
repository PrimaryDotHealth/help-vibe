# S15: chapters (categories). Top-level chapters carry a code.
class Admin::ChaptersController < Admin::BaseController
  before_action :require_publisher, except: :index
  before_action :set_chapter, only: %i[edit update]

  def index
    @chapters = Category.chapters.includes(:children)
    @counts = Article.live.group(:main_category_id).count
  end

  def new
    @chapter = Category.new(parent_id: params[:parent_id])
  end

  def create
    @chapter = Category.new(chapter_params)
    @chapter.save ? redirect_to(admin_chapters_path, notice: "Chapter created") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @chapter.update(chapter_params) ? redirect_to(admin_chapters_path, notice: "Saved") : render(:edit, status: :unprocessable_entity)
  end

  private
    def set_chapter = @chapter = Category.find_by!(slug: params[:id])
    def chapter_params = params.require(:category).permit(:name, :code, :slug, :description, :accessibility, :parent_id, :position)
end
