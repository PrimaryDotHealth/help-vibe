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
    if @chapter.save
      Activity.record!(@chapter, "create", by: Current.user)
      redirect_to(admin_chapters_path, notice: "Chapter created")
    else
      render(:new, status: :unprocessable_entity)
    end
  end

  def edit; end

  def update
    if @chapter.update(chapter_params)
      Activity.record!(@chapter, "update", by: Current.user)
      redirect_to(admin_chapters_path, notice: "Saved")
    else
      render(:edit, status: :unprocessable_entity)
    end
  end

  private
    def set_chapter = @chapter = Category.find_by!(slug: params[:id])
    def chapter_params = params.require(:category).permit(:name, :code, :slug, :description, :accessibility, :parent_id, :position)
end
