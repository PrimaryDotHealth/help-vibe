-- helpvibe migration 0001: knowledge base (Part 1). PostgreSQL 16+.
-- Decision 2026-11-03: Postgres replaces SQLite as the single database.
--
-- Conventions:
--   * ids are bigint identity (not uuid): Helpjuice's v3 API, which our app
--     already calls, uses integer ids. Public URLs use slugs and codes.
--   * every time is timestamptz, stored UTC.
--   * JSON is jsonb, flags are boolean, files are bytea (still one database to back up).
--   * case-insensitive text (emails, names that must be unique) is citext.
--   * status fields are text + check constraints (easier to migrate than enums).
--   * access: authz.rs checks every query (primary). Row-level security is added
--     as a backstop on PHI tables in 0002.

create extension if not exists citext;
create extension if not exists pg_trgm;

-- ---------------------------------------------------------------- settings
create table settings (
  key        text primary key,
  value      jsonb not null,
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------- users
create table users (
  id               bigint generated always as identity primary key,
  email            citext not null unique,
  first_name       text not null,
  last_name        text not null default '',
  role             text not null default 'viewer'
                   check (role in ('superadmin','admin','collaborator','draft_writer','viewer')),
  password_hash    text,                 -- argon2id. null = invited, or SSO-only
  active           boolean not null default true,
  failed_logins    integer not null default 0,
  locked_until     timestamptz,
  password_set_at  timestamptz,
  last_sign_in_at  timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

create table sessions (
  id            bigint generated always as identity primary key,
  token_hash    bytea not null unique,   -- sha256 of the cookie value
  user_id       bigint not null references users(id) on delete cascade,
  csrf_token    text not null,
  ip            inet,
  user_agent    text,
  created_at    timestamptz not null default now(),
  last_seen_at  timestamptz not null default now(),
  expires_at    timestamptz not null
);
create index sessions_user on sessions(user_id);
create index sessions_expires on sessions(expires_at);

create table password_tokens (           -- reset and invite links
  id          bigint generated always as identity primary key,
  token_hash  bytea not null unique,
  user_id     bigint not null references users(id) on delete cascade,
  purpose     text not null check (purpose in ('reset','invite')),
  expires_at  timestamptz not null,
  used_at     timestamptz,
  created_at  timestamptz not null default now()
);
create index password_tokens_user on password_tokens(user_id);

create table groups (
  id                 bigint generated always as identity primary key,
  name               citext not null unique,
  auto_join_domains  text[] not null default '{}',   -- e.g. {primary.health}
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

create table group_members (
  group_id   bigint not null references groups(id) on delete cascade,
  user_id    bigint not null references users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (group_id, user_id)
);
create index group_members_user on group_members(user_id);

-- ---------------------------------------------------------------- content
create table categories (
  id             bigint generated always as identity primary key,
  parent_id      bigint references categories(id) on delete restrict,  -- move or empty first
  slug           text not null unique,
  code           text unique check (code ~ '^[A-Z]{2,4}$'),            -- chapter code, top level only (SCH)
  name           text not null,
  description    text not null default '',
  accessibility  text not null default 'public'
                 check (accessibility in ('public','internal','private')),
  position       integer not null default 0,
  archived_at    timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  check (parent_id is null or parent_id <> id),     -- deeper cycles are checked in app code
  check (code is null or parent_id is null)         -- only chapters (top level) carry a code
);
create index categories_parent on categories(parent_id, position);

create table articles (
  id                bigint generated always as identity primary key,
  slug              text not null unique,
  code              text not null unique check (code ~ '^[A-Z]{2,4}·[0-9]{2,3}$'),  -- SCH·07, the signature
  accessibility     text not null default 'public'
                    check (accessibility in ('public','internal','private','url_only')),
  main_category_id  bigint not null references categories(id) on delete restrict,
  created_by_id     bigint references users(id) on delete set null,
  views             integer not null default 0,   -- denormalised counters, rebuilt from events nightly
  upvotes           integer not null default 0,
  downvotes         integer not null default 0,
  archived_at       timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index articles_main_category on articles(main_category_id);
create index articles_created_by on articles(created_by_id);
create index articles_updated on articles(updated_at);

create table article_categories (        -- "also in" categories. The main one is on articles.
  article_id   bigint not null references articles(id) on delete cascade,
  category_id  bigint not null references categories(id) on delete cascade,
  position     integer not null default 0,
  primary key (article_id, category_id)
);
create index article_categories_category on article_categories(category_id, position);

create table slug_redirects (            -- old slugs, old codes and imported Helpjuice paths keep working
  from_path   text primary key,          -- '/a/old-slug', 'SCH·04', '/en_US/billing/how-to-pay'
  article_id  bigint references articles(id) on delete cascade,
  category_id bigint references categories(id) on delete cascade,
  created_at  timestamptz not null default now(),
  check (num_nonnulls(article_id, category_id) = 1)
);
create index slug_redirects_article on slug_redirects(article_id);
create index slug_redirects_category on slug_redirects(category_id);

create table article_versions (
  id                   bigint generated always as identity primary key,
  article_id           bigint not null references articles(id) on delete cascade,
  number               integer not null,
  language             text not null default 'en_US',
  title                text not null,
  subtitle             text not null default '',
  status               text not null default 'draft'
                       check (status in ('draft','published','archived')),
  is_default           boolean not null default false,
  publish_at           timestamptz,        -- auto-publish
  expire_at            timestamptz,        -- auto-unpublish
  published_at         timestamptz,
  current_revision_id  bigint,             -- FK added after revisions exists
  created_by_id        bigint references users(id) on delete set null,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  unique (article_id, language, number),
  check (not is_default or status = 'published'),
  check (expire_at is null or publish_at is null or expire_at > publish_at)
);
-- exactly one live version per article per language
create unique index article_versions_one_default on article_versions(article_id, language) where is_default;
create index article_versions_article on article_versions(article_id, status);
create index article_versions_publish_at on article_versions(publish_at) where publish_at is not null and status = 'draft';
create index article_versions_expire_at on article_versions(expire_at) where expire_at is not null and status = 'published';
create index article_versions_created_by on article_versions(created_by_id);

create table revisions (
  id                bigint generated always as identity primary key,
  version_id        bigint not null references article_versions(id) on delete cascade,
  base_revision_id  bigint references revisions(id) on delete set null,  -- for the stale-save 409
  body              text not null,       -- sanitised HTML (canonical) or markdown source
  body_format       text not null default 'html' check (body_format in ('html','markdown')),
  body_text         text not null default '',   -- plain text, for search and diffs
  author_id         bigint references users(id) on delete set null,
  autosave          boolean not null default false,
  created_at        timestamptz not null default now()
);
create index revisions_version on revisions(version_id, created_at);
create index revisions_author on revisions(author_id);
create index revisions_base on revisions(base_revision_id);
alter table article_versions add constraint article_versions_current_revision
  foreign key (current_revision_id) references revisions(id) on delete set null;
create index article_versions_current_revision on article_versions(current_revision_id);

create table keywords (
  id    bigint generated always as identity primary key,
  name  citext not null unique
);
create table article_keywords (
  article_id  bigint not null references articles(id) on delete cascade,
  keyword_id  bigint not null references keywords(id) on delete cascade,
  primary key (article_id, keyword_id)
);
create index article_keywords_keyword on article_keywords(keyword_id);

-- who may see private content (also used for review assignment checks)
create table article_access (
  id          bigint generated always as identity primary key,
  article_id  bigint not null references articles(id) on delete cascade,
  user_id     bigint references users(id) on delete cascade,
  group_id    bigint references groups(id) on delete cascade,
  check (num_nonnulls(user_id, group_id) = 1)
);
create unique index article_access_user_u on article_access(article_id, user_id) where user_id is not null;
create unique index article_access_group_u on article_access(article_id, group_id) where group_id is not null;
create index article_access_user on article_access(user_id);
create index article_access_group on article_access(group_id);

create table category_access (
  id           bigint generated always as identity primary key,
  category_id  bigint not null references categories(id) on delete cascade,
  user_id      bigint references users(id) on delete cascade,
  group_id     bigint references groups(id) on delete cascade,
  check (num_nonnulls(user_id, group_id) = 1)
);
create unique index category_access_user_u on category_access(category_id, user_id) where user_id is not null;
create unique index category_access_group_u on category_access(category_id, group_id) where group_id is not null;
create index category_access_user on category_access(user_id);
create index category_access_group on category_access(group_id);

create table uploads (                   -- bytes live in the DB: one database to back up
  id              bigint generated always as identity primary key,
  sha256          bytea not null unique, -- dedupe identical files
  filename        text not null,
  content_type    text not null,
  size_bytes      integer not null check (size_bytes > 0 and size_bytes <= 26214400),  -- 25 MiB
  data            bytea not null,
  width           integer,
  height          integer,
  uploaded_by_id  bigint references users(id) on delete set null,
  created_at      timestamptz not null default now()
);
alter table uploads alter column data set storage external;   -- already compressed media: skip TOAST compression
create index uploads_uploaded_by on uploads(uploaded_by_id);

-- ---------------------------------------------------------------- review
create table reviews (
  id               bigint generated always as identity primary key,
  version_id       bigint not null references article_versions(id) on delete cascade,
  requested_by_id  bigint references users(id) on delete set null,
  note             text not null default '',
  rule             text not null check (rule in ('any','all')),  -- snapshot of the setting at request time
  status           text not null default 'pending'
                   check (status in ('pending','approved','changes_requested','cancelled')),
  created_at       timestamptz not null default now(),
  decided_at       timestamptz
);
create index reviews_version on reviews(version_id, status);
create index reviews_requested_by on reviews(requested_by_id);
create unique index reviews_one_pending on reviews(version_id) where status = 'pending';

create table review_assignments (
  id            bigint generated always as identity primary key,
  review_id     bigint not null references reviews(id) on delete cascade,
  user_id       bigint references users(id) on delete cascade,
  group_id      bigint references groups(id) on delete cascade,
  decision      text not null default 'pending'
                check (decision in ('pending','approved','changes_requested')),
  decided_by_id bigint references users(id) on delete set null,  -- the member who decided for a group
  message       text not null default '',
  decided_at    timestamptz,
  check (num_nonnulls(user_id, group_id) = 1)
);
create index review_assignments_review on review_assignments(review_id);
create index review_assignments_user on review_assignments(user_id, decision);
create index review_assignments_group on review_assignments(group_id, decision);
create index review_assignments_decided_by on review_assignments(decided_by_id);

create table comments (                  -- inline editor comments, internal only
  id           bigint generated always as identity primary key,
  version_id   bigint not null references article_versions(id) on delete cascade,
  parent_id    bigint references comments(id) on delete cascade,
  author_id    bigint references users(id) on delete set null,
  anchor       jsonb,                    -- {block_id, start, end, quote}; null on replies
  body         text not null,
  resolved_at  timestamptz,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index comments_version on comments(version_id, resolved_at);
create index comments_parent on comments(parent_id);
create index comments_author on comments(author_id);

-- ---------------------------------------------------------------- embed
create table context_rules (             -- host app page -> suggested articles in the widget
  id           bigint generated always as identity primary key,
  name         text not null,
  url_pattern  text not null,            -- glob on the host path, e.g. '/billing/*'
  priority     integer not null default 0,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index context_rules_priority on context_rules(priority desc);

create table context_rule_articles (
  rule_id     bigint not null references context_rules(id) on delete cascade,
  article_id  bigint not null references articles(id) on delete cascade,
  position    integer not null default 0,
  primary key (rule_id, article_id)
);
create index context_rule_articles_article on context_rule_articles(article_id);

-- ---------------------------------------------------------------- analytics & feedback
create table search_events (
  id                  bigint generated always as identity primary key,
  query               text,              -- null when the searcher is identified (PHI rule, setting)
  normalized          text,
  results_count       integer not null,
  outcome             text not null default 'bounced'
                      check (outcome in ('found','dead_end','bounced')),  -- updated on click
  clicked_article_id  bigint references articles(id) on delete set null,
  source              text not null check (source in ('kb','widget','api','admin')),
  page_context        text,              -- host path when from the widget
  visitor_hash        text,              -- daily-rotating hash, no raw IP stored
  user_id             bigint references users(id) on delete set null,
  created_at          timestamptz not null default now()
);
create index search_events_created on search_events(created_at);
create index search_events_normalized on search_events(normalized, created_at);
create index search_events_outcome on search_events(outcome, created_at);
create index search_events_clicked on search_events(clicked_article_id);
create index search_events_user on search_events(user_id);

create table view_events (
  id               bigint generated always as identity primary key,
  article_id       bigint not null references articles(id) on delete cascade,
  version_id       bigint references article_versions(id) on delete set null,
  search_event_id  bigint references search_events(id) on delete set null,
  source           text not null check (source in ('kb','widget','embed','api')),
  page_context     text,
  seconds_spent    integer not null default 0,
  read             boolean not null default false,   -- scrolled to end or 30s+
  visitor_hash     text,
  user_id          bigint references users(id) on delete set null,
  created_at       timestamptz not null default now()
);
create index view_events_article on view_events(article_id, created_at);
create index view_events_created on view_events(created_at);
create index view_events_version on view_events(version_id);
create index view_events_search on view_events(search_event_id);
create index view_events_user on view_events(user_id);

create table votes (
  id            bigint generated always as identity primary key,
  article_id    bigint not null references articles(id) on delete cascade,
  value         smallint not null check (value in (-1, 1)),
  comment       text not null default '',
  source        text not null check (source in ('kb','widget','embed','api')),
  visitor_hash  text not null,           -- one vote per visitor per article
  user_id       bigint references users(id) on delete set null,
  created_at    timestamptz not null default now(),
  unique (article_id, visitor_hash)
);
create index votes_article on votes(article_id, created_at);
create index votes_user on votes(user_id);

create table contact_requests (          -- Part 1 contact form. Replaced by conversations in Part 2.
  id               bigint generated always as identity primary key,
  name             text not null,
  email            citext not null,
  subject          text not null default '',
  body             text not null,
  search_event_id  bigint references search_events(id) on delete set null,
  page_context     text,
  emailed_at       timestamptz,
  created_at       timestamptz not null default now()
);
create index contact_requests_created on contact_requests(created_at);
create index contact_requests_search on contact_requests(search_event_id);

-- ---------------------------------------------------------------- developers
create table api_keys (
  id             bigint generated always as identity primary key,
  name           text not null,
  prefix         text not null,          -- first 8 chars, shown in the UI
  token_hash     bytea not null unique,
  scope          text not null default 'read' check (scope in ('read','write')),
  created_by_id  bigint references users(id) on delete set null,
  last_used_at   timestamptz,
  revoked_at     timestamptz,
  created_at     timestamptz not null default now()
);
create index api_keys_created_by on api_keys(created_by_id);

create table activities (                -- content audit log and webhook source
  id              bigint generated always as identity primary key,
  trackable_type  text not null check (trackable_type in ('article','category','user','group','comment','review','setting')),
  trackable_id    bigint not null,
  owner_id        bigint references users(id) on delete set null,
  action          text not null,         -- create, update, delete, publish, archive, unpublish, approve...
  automatic       boolean not null default false,
  extra           jsonb not null default '{}',
  created_at      timestamptz not null default now()
);
create index activities_trackable on activities(trackable_type, trackable_id, created_at);
create index activities_owner on activities(owner_id, created_at);
create index activities_created on activities(created_at);

create table webhooks (
  id                  bigint generated always as identity primary key,
  url                 text not null,
  event               text not null check (event in (
                        'user_create','user_update','user_delete',
                        'question_create','question_update','question_delete','question_archive','question_publish',
                        'comment_create','comment_update','comment_delete',
                        'category_create','category_update','category_delete')),   -- Helpjuice's names; 0002 adds support events
  secret              text not null,     -- HMAC-SHA256 signing key, encrypted at the app layer
  enabled             boolean not null default true,
  last_response_code  integer,
  created_by_id       bigint references users(id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);
create index webhooks_event on webhooks(event) where enabled;
create index webhooks_created_by on webhooks(created_by_id);

create table webhook_deliveries (
  id              bigint generated always as identity primary key,
  webhook_id      bigint not null references webhooks(id) on delete cascade,
  activity_id     bigint not null references activities(id) on delete cascade,
  attempt         integer not null default 0,
  status          text not null default 'pending' check (status in ('pending','delivered','failed','dead')),
  response_code   integer,
  error           text,
  next_attempt_at timestamptz not null default now(),
  delivered_at    timestamptz,
  created_at      timestamptz not null default now(),
  unique (webhook_id, activity_id)       -- never enqueue the same event twice
);
create index webhook_deliveries_due on webhook_deliveries(next_attempt_at) where status in ('pending','failed');
create index webhook_deliveries_activity on webhook_deliveries(activity_id);

-- ---------------------------------------------------------------- import (Helpjuice -> helpvibe)
create table import_runs (
  id            bigint generated always as identity primary key,
  source        text not null default 'helpjuice',
  status        text not null default 'running' check (status in ('running','done','failed')),
  stats         jsonb not null default '{}',
  error         text,
  started_by_id bigint references users(id) on delete set null,
  started_at    timestamptz not null default now(),
  finished_at   timestamptz
);
create index import_runs_started_by on import_runs(started_by_id);

create table import_map (                -- makes re-runs idempotent, and drives link rewriting
  source       text not null,
  source_type  text not null check (source_type in ('article','category','user','group','upload')),
  source_id    text not null,
  local_id     bigint not null,
  run_id       bigint references import_runs(id) on delete set null,
  primary key (source, source_type, source_id)
);
create index import_map_run on import_map(run_id);

-- ---------------------------------------------------------------- search index
-- One row per live (default, published) version, maintained by app code on
-- publish/unpublish/archive (which version is live is app logic). Visibility
-- is filtered by joining articles, in SQL, never after the fact.
create table search_index (
  version_id  bigint primary key references article_versions(id) on delete cascade,
  article_id  bigint not null references articles(id) on delete cascade,
  language    text not null,
  code        text not null,
  title       text not null,
  subtitle    text not null default '',
  keywords    text not null default '',
  body        text not null default '',
  document    tsvector generated always as (
                setweight(to_tsvector('english', title), 'A') ||
                setweight(to_tsvector('english', keywords), 'A') ||
                setweight(to_tsvector('english', subtitle), 'B') ||
                setweight(to_tsvector('english', body), 'C')
              ) stored,
  updated_at  timestamptz not null default now(),
  unique (article_id, language)
);
create index search_index_document on search_index using gin (document);
-- typo fallback (pg_trgm): used when the full-text query returns nothing
create index search_index_trgm on search_index using gin ((title || ' ' || keywords) gin_trgm_ops);
-- exact code lookup: "SCH·07", "sch07"
create index search_index_code on search_index(code);
