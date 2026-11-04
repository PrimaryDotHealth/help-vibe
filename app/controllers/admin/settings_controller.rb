# S18: knowledge-base settings (review rules for now). Admins only.
class Admin::SettingsController < Admin::BaseController
  before_action { head :forbidden unless Current.user.admin? }

  def show; end

  def update
    Setting["review.rule"] = params[:review_rule] == "all" ? "all" : "any"
    Setting["review.required"] = params[:review_required] == "1"
    Setting["review.bypass_roles"] = Array(params[:bypass_roles]) & %w[superadmin admin collaborator]
    Activity.create!(trackable_type: "setting", trackable_id: 0, owner: Current.user, action: "update", extra: { section: "review" })
    redirect_to admin_settings_path, notice: "Saved"
  end
end
