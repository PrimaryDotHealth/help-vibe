# Helpjuice-shaped read API (replica/architecture.md, "API").
# Auth: `Authorization: <key>`, `Authorization: Bearer <key>` or `?api_key=`.
# A key reads public and staff-only content (never private), 100 requests/min.
class Api::V3::BaseController < ActionController::API
  ACCESSIBILITY_CODES = { "public" => 1, "internal" => 0, "private" => 2, "url_only" => 4 }.freeze

  before_action :authenticate_key
  rate_limit to: 100, within: 1.minute, by: -> { @api_key.id }, with: -> { render_error(429, "Rate limit exceeded: 100 requests per minute") }

  rescue_from(ActiveRecord::RecordNotFound) { render_error(404, "Not found") }

  private
    def authenticate_key
      token = request.authorization.to_s.delete_prefix("Bearer ").strip.presence || params[:api_key]
      @api_key = ApiKey.authenticate(token)
      return render_error(token.present? ? 401 : 403, token.present? ? "Invalid API key" : "API key not provided") unless @api_key
      @api_key.touch_used!
    end

    def viewer = Visibility::Viewer.staff_token

    def render_error(status, message)
      render json: { errors: [ message ] }, status: status
    end

    def limit = params.fetch(:limit, 25).to_i.clamp(1, 1000)
    def page = [ params.fetch(:page, 1).to_i, 1 ].max

    def paginate(scope, key)
      total = scope.count
      records = scope.offset((page - 1) * limit).limit(limit)
      { meta: { current: page, limit: limit, total_pages: (total.to_f / limit).ceil, total_count: total },
        key => records.map { yield _1 } }
    end

    def access_code(value) = ACCESSIBILITY_CODES.fetch(value)
end
