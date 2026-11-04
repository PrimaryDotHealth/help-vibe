# Direct uploads (images and files dropped into the editor) are for signed-in
# editors only, at most 25 MiB, and only common document/media types.
# Active Storage's own endpoint is open to anyone by default.
Rails.application.config.to_prepare do
  ActiveStorage::DirectUploadsController.class_eval do
    MAX_UPLOAD_BYTES = 25.megabytes unless const_defined?(:MAX_UPLOAD_BYTES)
    ALLOWED_UPLOAD_TYPES = %r{\A(image/(png|jpeg|gif|webp)|application/pdf|video/(mp4|webm)|text/plain|text/csv)\z} unless const_defined?(:ALLOWED_UPLOAD_TYPES)

    before_action :require_signed_in_editor
    before_action :check_upload_limits

    private
      def require_signed_in_editor
        user = Session.find_by(id: cookies.signed[:session_id])&.user
        head :forbidden unless user&.active? && user.editor?
      end

      def check_upload_limits
        blob = params.require(:blob)
        return head(:content_too_large) if blob[:byte_size].to_i > MAX_UPLOAD_BYTES
        head :unsupported_media_type unless blob[:content_type].to_s.match?(ALLOWED_UPLOAD_TYPES)
      end
  end
end
