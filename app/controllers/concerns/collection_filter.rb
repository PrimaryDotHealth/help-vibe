# ?collections=acme,general on any help center or widget page limits what it
# shows to articles in those collections. No parameter: everything.
#
# The parameter rides along on every link, redirect and form the page builds
# (default_url_options, plus collection_field for GET search forms), so a
# reader clicking around inside an iframe stays in the same collections.
# Unknown slugs match nothing, so a typo shows less, never more.
module CollectionFilter
  extend ActiveSupport::Concern

  included { helper_method :collection_filter }

  private
    # The requested collections, or nil when there's no filter.
    def collection_filter
      return @collection_filter if defined?(@collection_filter)
      @collection_filter = (Collection.where(slug: collection_slugs).order(:name).to_a if collection_slugs.any?)
    end

    def collection_slugs = @collection_slugs ||= Collection.slugs_from(params[:collections])

    # The value to carry on links ("acme,general"), or nil.
    def collection_param = collection_slugs.join(",").presence

    def default_url_options
      collection_param ? super.merge(collections: collection_param) : super
    end

    def within_collections(viewer)
      collection_filter ? viewer.in_collections(collection_filter.map(&:id)) : viewer
    end
end
