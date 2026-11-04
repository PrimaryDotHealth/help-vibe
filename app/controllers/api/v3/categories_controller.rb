class Api::V3::CategoriesController < Api::V3::BaseController
  include Rails.application.routes.url_helpers

  def index
    render json: paginate(scope.order(:parent_id, :position, :id), :categories) { category_json(_1) }
  end

  def show
    render json: { category: category_json(scope.find(params[:id])) }
  end

  before_action :require_write, only: %i[create update]

  def create
    attrs = category_params
    category = Category.create!(name: attrs[:name], description: attrs[:description].to_s, parent_id: attrs[:parent_id],
                                slug: attrs[:codename].presence, code: attrs[:parent_id].present? ? nil : attrs[:code],
                                accessibility: ACCESSIBILITY_CODES.key(attrs[:accessibility].to_i) || "public")
    Activity.record!(category, "create", extra: { api_key: @api_key.prefix })
    render json: { category: category_json(category) }, status: :created
  rescue ActiveRecord::RecordInvalid => e
    render_error(422, e.record.errors.full_messages.to_sentence)
  end

  def update
    category = Category.find(params[:id])
    attrs = category_params
    changes = { name: attrs[:name], description: attrs[:description], slug: attrs[:codename].presence }.compact
    changes[:accessibility] = ACCESSIBILITY_CODES.key(attrs[:accessibility].to_i) if attrs[:accessibility].present?
    category.update!(changes)
    Activity.record!(category, "update", extra: { api_key: @api_key.prefix })
    render json: { category: category_json(category) }
  rescue ActiveRecord::RecordInvalid => e
    render_error(422, e.record.errors.full_messages.to_sentence)
  end

  private
    def scope = Category.where(Visibility.category_sql(viewer))
    def category_params = params.fetch(:category, params).permit(:name, :description, :codename, :code, :parent_id, :accessibility)

    def category_json(c)
      { id: c.id, name: c.name, codename: c.slug, code: c.code, parent_id: c.parent_id, description: c.description,
        accessibility: access_code(c.accessibility), url: chapter_url(c, host: request.base_url) }
    end
end
