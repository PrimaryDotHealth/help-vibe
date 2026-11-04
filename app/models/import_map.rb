# Source id -> our id, so re-running an import updates instead of duplicating.
class ImportMap < ApplicationRecord
  self.table_name = "import_map"
  self.primary_key = %i[source source_type source_id]
end
