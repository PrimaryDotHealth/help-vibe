# S22: import from Helpjuice. The API key comes from the server environment,
# never from this form, so it isn't stored or logged by the app.
class Admin::ImportController < Admin::BaseController
  before_action { head :forbidden unless Current.user.superadmin? }

  def show
    @runs = ImportRun.recent.limit(10)
    @configured = ENV["HELPJUICE_SUBDOMAIN"].present? && ENV["HELPJUICE_API_KEY"].present?
  end

  def create
    return redirect_to(admin_import_path, alert: "Set HELPJUICE_SUBDOMAIN and HELPJUICE_API_KEY on the server first") unless ENV["HELPJUICE_SUBDOMAIN"].present? && ENV["HELPJUICE_API_KEY"].present?
    return redirect_to(admin_import_path, alert: "An import is already running") if ImportRun.where(status: "running").exists?
    run = ImportRun.create!(source: "helpjuice", started_by: Current.user)
    ImportHelpjuiceJob.perform_later(run.id, users: params[:users] == "1", images: params[:images] != "0")
    redirect_to admin_import_path, notice: "Import started"
  end

  # Import a Helpjuice HTML export (a folder, or one .html file plus its metadata.json) from S3.
  # Only s3:// paths are accepted here: this form must never read files off the server's disk.
  def html
    location, metadata = params[:location].to_s.strip, params[:metadata].to_s.strip.presence
    unless [ location, metadata ].compact.all? { _1.match?(Helpvibe::Importers::HelpjuiceHtml::LOCATION) }
      return redirect_to(admin_import_path, alert: "Enter an S3 path like s3://your-bucket/helpjuice-export/")
    end
    return redirect_to(admin_import_path, alert: "An import is already running") if ImportRun.where(status: "running").exists?
    run = ImportRun.create!(source: "helpjuice_html", started_by: Current.user)
    ImportHelpjuiceHtmlJob.perform_later(run.id, location, metadata: metadata, images: params[:images] == "1")
    redirect_to admin_import_path, notice: "Import started"
  end
end
