# Postgres full-text search over live article versions (table search_index,
# one row per article per language, with a generated weighted tsvector).
# Rows are written with SQL because `document` is a generated column.
class SearchIndex < ApplicationRecord
  self.table_name = "search_index"
  self.primary_key = "version_id"
  self.ignored_columns += [ "document" ]

  belongs_to :article
  belongs_to :version, class_name: "ArticleVersion"

  Result = Data.define(:article_id, :code, :slug, :title, :subtitle, :chapter, :snippet, :rank)

  def self.refresh!(version)
    article = version.article
    connection.exec_query(<<~SQL, "SearchIndex refresh", [ version.id, article.id, version.language, article.code, version.title, version.subtitle.to_s, article.keyword_list.tr(",", " "), version.current_revision&.body_text.to_s ])
      insert into search_index (version_id, article_id, language, code, title, subtitle, keywords, body, updated_at)
      values ($1, $2, $3, $4, $5, $6, $7, $8, now())
      on conflict (article_id, language) do update set
        version_id = excluded.version_id, code = excluded.code, title = excluded.title, subtitle = excluded.subtitle,
        keywords = excluded.keywords, body = excluded.body, updated_at = now()
    SQL
  end

  def self.remove!(article, language)
    where(article_id: article.id, language: language).delete_all
  end

  # Returns [results, fuzzy?]. Visibility is filtered in SQL, never afterwards,
  # so counts and pagination can't leak hidden articles.
  def self.search(query, viewer:, category_id: nil, limit: 25)
    q = query.to_s.strip
    return [ [], false ] if q.blank?

    results = full_text(q, viewer:, category_id:, limit:)
    return [ results, false ] if results.any?
    [ fuzzy(q, viewer:, category_id:, limit:), true ]
  end

  def self.full_text(q, viewer:, category_id:, limit:)
    rows = connection.select_all(sanitize_sql_array([ <<~SQL, { q:, limit:, category_id: } ]))
      with query as (select websearch_to_tsquery('english', :q) as tsq)
      select si.article_id, si.code, a.slug, si.title, si.subtitle, c.name as chapter,
             ts_headline('english', si.body, query.tsq,
               'StartSel=<mark>, StopSel=</mark>, MaxWords=28, MinWords=12, MaxFragments=1') as snippet,
             ts_rank_cd(si.document, query.tsq) * (1 + ln(1 + a.upvotes)) as rank
      from search_index si
      join articles a on a.id = si.article_id
      join categories c on c.id = a.main_category_id
      cross join query
      where si.document @@ query.tsq
        and #{visibility_sql(viewer)}
        #{"and (a.main_category_id = :category_id or c.parent_id = :category_id)" if category_id}
      order by rank desc
      limit :limit
    SQL
    rows.map { to_result(_1) }
  end

  def self.fuzzy(q, viewer:, category_id:, limit:)
    rows = connection.select_all(sanitize_sql_array([ <<~SQL, { q:, limit:, category_id: } ]))
      select si.article_id, si.code, a.slug, si.title, si.subtitle, c.name as chapter,
             left(si.body, 180) as snippet,
             word_similarity(:q, si.title || ' ' || si.keywords) as rank
      from search_index si
      join articles a on a.id = si.article_id
      join categories c on c.id = a.main_category_id
      where :q <% (si.title || ' ' || si.keywords)
        and #{visibility_sql(viewer)}
        #{"and (a.main_category_id = :category_id or c.parent_id = :category_id)" if category_id}
      order by rank desc
      limit :limit
    SQL
    rows.map { to_result(_1) }
  end

  def self.visibility_sql(viewer)
    list = Visibility.listed(viewer).map { connection.quote(_1) }.join(", ")
    "a.archived_at is null and c.archived_at is null and a.accessibility in (#{list}) and c.accessibility in (#{list})"
  end

  def self.to_result(row)
    Result.new(article_id: row["article_id"], code: row["code"], slug: row["slug"], title: row["title"],
               subtitle: row["subtitle"], chapter: row["chapter"], snippet: row["snippet"], rank: row["rank"].to_f)
  end
end
