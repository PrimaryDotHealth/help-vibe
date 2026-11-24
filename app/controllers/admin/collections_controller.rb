# Collections: sets of articles an embed can be limited to
# (?collections=acme,general). Publishers manage them; editors can look.
class Admin::CollectionsController < Admin::BaseController
  before_action :require_publisher, except: :index
  before_action :set_collection, only: %i[edit update destroy]

  def index
    @collections = Collection.order(:name)
    @counts = ArticleCollection.joins(:article).merge(Article.live).group(:collection_id).count
  end

  def new = @collection = Collection.new

  def create
    @collection = Collection.new(collection_params)
    @collection.save ? redirect_to(admin_collections_path, notice: "Collection created") : render(:new, status: :unprocessable_entity)
  end

  def edit; end

  def update
    @collection.update(collection_params) ? redirect_to(admin_collections_path, notice: "Saved") : render(:edit, status: :unprocessable_entity)
  end

  def destroy
    @collection.destroy!
    redirect_to admin_collections_path, notice: "Collection deleted"
  end

  private
    def set_collection = @collection = Collection.find_by!(slug: params[:id])
    def collection_params = params.require(:collection).permit(:name, :slug, :description)
end
