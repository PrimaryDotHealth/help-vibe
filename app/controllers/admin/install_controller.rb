# "Install" pages: how to put the help widget (Helpdesk) and articles
# (Articles) into our app or website. Admins only; nothing secret is shown.
class Admin::InstallController < Admin::BaseController
  skip_before_action :require_editor
  before_action { redirect_to(admin_root_path, alert: "Only admins can see install instructions") unless Current.user&.active? && Current.user.admin? }
  before_action :load_settings

  def helpdesk; end

  def articles
    # A real public article makes the examples copy-and-paste ready.
    @example = Article.listed_for(Visibility::Viewer.anonymous).order(:id).first
  end

  private
    def load_settings
      @script_url = embed_script_url
      @frame_ancestors = Frameable.frame_ancestors
      @secret_set = ENV["HELPVIBE_WIDGET_SECRET"].present?
      @collections = Collection.order(:name).to_a
      @collection_example = @collections.first(2).map(&:slug).join(",").presence || "acme,general"
    end
end
