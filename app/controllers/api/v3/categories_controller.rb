class Api::V3::CategoriesController < Api::V3::BaseController
  include Rails.application.routes.url_helpers

  def index
    render json: paginate(scope.order(:parent_id, :position, :id), :categories) { category_json(_1) }
  end

  def show
    render json: { category: category_json(scope.find(params[:id])) }
  end

  private
    def scope = Category.where(Visibility.category_sql(viewer))

    def category_json(c)
      { id: c.id, name: c.name, codename: c.slug, code: c.code, parent_id: c.parent_id, description: c.description,
        accessibility: access_code(c.accessibility), url: chapter_url(c, host: request.base_url) }
    end
end
