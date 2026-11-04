# S20 (part 1): API keys. Admins only. The token is shown once, after creation.
class Admin::ApiKeysController < Admin::BaseController
  before_action { head :forbidden unless Current.user.admin? }

  def index
    @keys = ApiKey.includes(:created_by).order(revoked_at: :desc, created_at: :desc)
    @new_token = flash[:api_token]
  end

  def create
    key = ApiKey.create!(name: params.require(:api_key)[:name].presence || "Unnamed key", scope: "read", created_by: Current.user)
    flash[:api_token] = key.token
    redirect_to admin_api_keys_path
  end

  def destroy
    ApiKey.find(params[:id]).revoke!
    redirect_to admin_api_keys_path, notice: "Key revoked"
  end
end
