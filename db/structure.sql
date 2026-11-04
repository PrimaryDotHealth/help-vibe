SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: citext; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;


--
-- Name: EXTENSION citext; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION citext IS 'data type for case-insensitive character strings';


--
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: app_actor_type(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_actor_type() RETURNS text
    LANGUAGE sql STABLE
    AS $$ select coalesce(current_setting('app.actor_type', true), '') $$;


--
-- Name: app_contact_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_contact_id() RETURNS bigint
    LANGUAGE sql STABLE
    AS $$ select nullif(current_setting('app.contact_id', true), '')::bigint $$;


--
-- Name: app_flag(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_flag(name text) RETURNS boolean
    LANGUAGE sql STABLE
    AS $$ select coalesce(current_setting('app.' || name, true), '') = 'on' $$;


--
-- Name: app_user_id(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.app_user_id() RETURNS bigint
    LANGUAGE sql STABLE
    AS $$ select nullif(current_setting('app.user_id', true), '')::bigint $$;


--
-- Name: audit_events_guard(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.audit_events_guard() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
  if tg_op = 'UPDATE' then
    raise exception 'audit_events is append-only';
  end if;
  if old.at > now() - interval '6 years' then
    raise exception 'audit_events younger than 6 years cannot be deleted';
  end if;
  return old;
end $$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: action_mailbox_inbound_emails; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.action_mailbox_inbound_emails (
    id bigint NOT NULL,
    status integer DEFAULT 0 NOT NULL,
    message_id character varying NOT NULL,
    message_checksum character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: action_mailbox_inbound_emails_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.action_mailbox_inbound_emails_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: action_mailbox_inbound_emails_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.action_mailbox_inbound_emails_id_seq OWNED BY public.action_mailbox_inbound_emails.id;


--
-- Name: action_text_rich_texts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.action_text_rich_texts (
    id bigint NOT NULL,
    name character varying NOT NULL,
    body text,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: action_text_rich_texts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.action_text_rich_texts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: action_text_rich_texts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.action_text_rich_texts_id_seq OWNED BY public.action_text_rich_texts.id;


--
-- Name: active_storage_attachments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_attachments (
    id bigint NOT NULL,
    name character varying NOT NULL,
    record_type character varying NOT NULL,
    record_id bigint NOT NULL,
    blob_id bigint NOT NULL,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_attachments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_attachments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_attachments_id_seq OWNED BY public.active_storage_attachments.id;


--
-- Name: active_storage_blobs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_blobs (
    id bigint NOT NULL,
    key character varying NOT NULL,
    filename character varying NOT NULL,
    content_type character varying,
    metadata text,
    service_name character varying NOT NULL,
    byte_size bigint NOT NULL,
    checksum character varying,
    created_at timestamp(6) without time zone NOT NULL
);


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_blobs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_blobs_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_blobs_id_seq OWNED BY public.active_storage_blobs.id;


--
-- Name: active_storage_variant_records; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_storage_variant_records (
    id bigint NOT NULL,
    blob_id bigint NOT NULL,
    variation_digest character varying NOT NULL
);


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.active_storage_variant_records_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: active_storage_variant_records_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.active_storage_variant_records_id_seq OWNED BY public.active_storage_variant_records.id;


--
-- Name: activities; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activities (
    id bigint NOT NULL,
    trackable_type text NOT NULL,
    trackable_id bigint NOT NULL,
    owner_id bigint,
    action text NOT NULL,
    automatic boolean DEFAULT false NOT NULL,
    extra jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT activities_trackable_type_check CHECK ((trackable_type = ANY (ARRAY['article'::text, 'category'::text, 'user'::text, 'group'::text, 'comment'::text, 'review'::text, 'setting'::text])))
);


--
-- Name: activities_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.activities ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.activities_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: api_keys; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.api_keys (
    id bigint NOT NULL,
    name text NOT NULL,
    prefix text NOT NULL,
    token_hash bytea NOT NULL,
    scope text DEFAULT 'read'::text NOT NULL,
    created_by_id bigint,
    last_used_at timestamp with time zone,
    revoked_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT api_keys_scope_check CHECK ((scope = ANY (ARRAY['read'::text, 'write'::text])))
);


--
-- Name: api_keys_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.api_keys ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.api_keys_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ar_internal_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ar_internal_metadata (
    key character varying NOT NULL,
    value character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: article_access; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.article_access (
    id bigint NOT NULL,
    article_id bigint NOT NULL,
    user_id bigint,
    group_id bigint,
    CONSTRAINT article_access_check CHECK ((num_nonnulls(user_id, group_id) = 1))
);


--
-- Name: article_access_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.article_access ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.article_access_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: article_categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.article_categories (
    article_id bigint NOT NULL,
    category_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL
);


--
-- Name: article_keywords; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.article_keywords (
    article_id bigint NOT NULL,
    keyword_id bigint NOT NULL
);


--
-- Name: article_versions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.article_versions (
    id bigint NOT NULL,
    article_id bigint NOT NULL,
    number integer NOT NULL,
    language text DEFAULT 'en_US'::text NOT NULL,
    title text NOT NULL,
    subtitle text DEFAULT ''::text NOT NULL,
    status text DEFAULT 'draft'::text NOT NULL,
    is_default boolean DEFAULT false NOT NULL,
    publish_at timestamp with time zone,
    expire_at timestamp with time zone,
    published_at timestamp with time zone,
    current_revision_id bigint,
    created_by_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT article_versions_check CHECK (((NOT is_default) OR (status = 'published'::text))),
    CONSTRAINT article_versions_check1 CHECK (((expire_at IS NULL) OR (publish_at IS NULL) OR (expire_at > publish_at))),
    CONSTRAINT article_versions_status_check CHECK ((status = ANY (ARRAY['draft'::text, 'published'::text, 'archived'::text])))
);


--
-- Name: article_versions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.article_versions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.article_versions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.articles (
    id bigint NOT NULL,
    slug text NOT NULL,
    code text NOT NULL,
    accessibility text DEFAULT 'public'::text NOT NULL,
    main_category_id bigint NOT NULL,
    created_by_id bigint,
    views integer DEFAULT 0 NOT NULL,
    upvotes integer DEFAULT 0 NOT NULL,
    downvotes integer DEFAULT 0 NOT NULL,
    archived_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT articles_accessibility_check CHECK ((accessibility = ANY (ARRAY['public'::text, 'internal'::text, 'private'::text, 'url_only'::text]))),
    CONSTRAINT articles_code_check CHECK ((code ~ '^[A-Z]{2,4}·[0-9]{2,3}$'::text))
);


--
-- Name: articles_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.articles ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.articles_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: audit_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.audit_events (
    id bigint NOT NULL,
    actor_type text NOT NULL,
    actor_id bigint,
    actor_label text NOT NULL,
    action text NOT NULL,
    subject_type text NOT NULL,
    subject_id bigint,
    ip inet,
    user_agent text,
    detail jsonb DEFAULT '{}'::jsonb NOT NULL,
    at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT audit_events_action_check CHECK ((action = ANY (ARRAY['view'::text, 'create'::text, 'update'::text, 'delete'::text, 'export'::text, 'sign_in'::text, 'sign_in_failed'::text, 'assign'::text, 'download'::text]))),
    CONSTRAINT audit_events_actor_type_check CHECK ((actor_type = ANY (ARRAY['user'::text, 'contact'::text, 'api_key'::text, 'system'::text]))),
    CONSTRAINT audit_events_subject_type_check CHECK ((subject_type = ANY (ARRAY['thread'::text, 'contact'::text, 'upload'::text, 'report'::text, 'user'::text, 'session'::text])))
);


--
-- Name: audit_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.audit_events ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.audit_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: categories; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    parent_id bigint,
    slug text NOT NULL,
    code text,
    name text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    accessibility text DEFAULT 'public'::text NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT categories_accessibility_check CHECK ((accessibility = ANY (ARRAY['public'::text, 'internal'::text, 'private'::text]))),
    CONSTRAINT categories_check CHECK (((parent_id IS NULL) OR (parent_id <> id))),
    CONSTRAINT categories_check1 CHECK (((code IS NULL) OR (parent_id IS NULL))),
    CONSTRAINT categories_code_check CHECK ((code ~ '^[A-Z]{2,4}$'::text))
);


--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.categories ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: category_access; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.category_access (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    user_id bigint,
    group_id bigint,
    CONSTRAINT category_access_check CHECK ((num_nonnulls(user_id, group_id) = 1))
);


--
-- Name: category_access_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.category_access ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.category_access_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.comments (
    id bigint NOT NULL,
    version_id bigint NOT NULL,
    parent_id bigint,
    author_id bigint,
    anchor jsonb,
    body text NOT NULL,
    resolved_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: comments_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.comments ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.comments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: companies; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.companies (
    id bigint NOT NULL,
    external_id text,
    name text NOT NULL,
    app_attributes jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: companies_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.companies ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.companies_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: contact_requests; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contact_requests (
    id bigint NOT NULL,
    name text NOT NULL,
    email public.citext NOT NULL,
    subject text DEFAULT ''::text NOT NULL,
    body text NOT NULL,
    search_event_id bigint,
    page_context text,
    emailed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: contact_requests_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.contact_requests ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.contact_requests_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: contacts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.contacts (
    id bigint NOT NULL,
    external_id text,
    email public.citext,
    name text DEFAULT ''::text NOT NULL,
    kind text DEFAULT 'unknown'::text NOT NULL,
    company_id bigint,
    app_attributes jsonb DEFAULT '{}'::jsonb NOT NULL,
    email_verified_at timestamp with time zone,
    last_seen_at timestamp with time zone,
    deleted_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT contacts_check CHECK ((num_nonnulls(external_id, email) >= 1)),
    CONSTRAINT contacts_kind_check CHECK ((kind = ANY (ARRAY['patient'::text, 'staff'::text, 'unknown'::text])))
);


--
-- Name: contacts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.contacts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.contacts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: context_rule_articles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.context_rule_articles (
    rule_id bigint NOT NULL,
    article_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL
);


--
-- Name: context_rules; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.context_rules (
    id bigint NOT NULL,
    name text NOT NULL,
    url_pattern text NOT NULL,
    priority integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: context_rules_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.context_rules ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.context_rules_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: group_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.group_members (
    group_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: groups; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.groups (
    id bigint NOT NULL,
    name public.citext NOT NULL,
    auto_join_domains text[] DEFAULT '{}'::text[] NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: groups_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.groups ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.groups_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: import_map; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_map (
    source text NOT NULL,
    source_type text NOT NULL,
    source_id text NOT NULL,
    local_id bigint NOT NULL,
    run_id bigint,
    CONSTRAINT import_map_source_type_check CHECK ((source_type = ANY (ARRAY['article'::text, 'category'::text, 'user'::text, 'group'::text, 'upload'::text])))
);


--
-- Name: import_runs; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.import_runs (
    id bigint NOT NULL,
    source text DEFAULT 'helpjuice'::text NOT NULL,
    status text DEFAULT 'running'::text NOT NULL,
    stats jsonb DEFAULT '{}'::jsonb NOT NULL,
    error text,
    started_by_id bigint,
    started_at timestamp with time zone DEFAULT now() NOT NULL,
    finished_at timestamp with time zone,
    CONSTRAINT import_runs_status_check CHECK ((status = ANY (ARRAY['running'::text, 'done'::text, 'failed'::text])))
);


--
-- Name: import_runs_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.import_runs ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.import_runs_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: keywords; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.keywords (
    id bigint NOT NULL,
    name public.citext NOT NULL
);


--
-- Name: keywords_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.keywords ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.keywords_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: macros; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.macros (
    id bigint NOT NULL,
    name text NOT NULL,
    body text DEFAULT ''::text NOT NULL,
    actions jsonb DEFAULT '[]'::jsonb NOT NULL,
    team_id bigint,
    created_by_id bigint,
    uses integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: macros_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.macros ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.macros_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: mentions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.mentions (
    id bigint NOT NULL,
    part_id bigint NOT NULL,
    user_id bigint NOT NULL,
    read_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: mentions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.mentions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.mentions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: notifications; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.notifications (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    thread_id bigint,
    kind text NOT NULL,
    read_at timestamp with time zone,
    emailed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT notifications_kind_check CHECK ((kind = ANY (ARRAY['assigned'::text, 'mentioned'::text, 'replied'::text, 'sla_at_risk'::text, 'sla_missed'::text, 'handoff_resolved'::text])))
);


--
-- Name: notifications_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.notifications ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.notifications_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: revisions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.revisions (
    id bigint NOT NULL,
    version_id bigint NOT NULL,
    base_revision_id bigint,
    markdown_source text,
    body_format text DEFAULT 'html'::text NOT NULL,
    body_text text DEFAULT ''::text NOT NULL,
    author_id bigint,
    autosave boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT revisions_body_format_check CHECK ((body_format = ANY (ARRAY['html'::text, 'markdown'::text])))
);


--
-- Name: revisions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.revisions ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.revisions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: search_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_events (
    id bigint NOT NULL,
    query text,
    normalized text,
    results_count integer NOT NULL,
    outcome text DEFAULT 'bounced'::text NOT NULL,
    clicked_article_id bigint,
    source text NOT NULL,
    page_context text,
    visitor_hash text,
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT search_events_outcome_check CHECK ((outcome = ANY (ARRAY['found'::text, 'dead_end'::text, 'bounced'::text]))),
    CONSTRAINT search_events_source_check CHECK ((source = ANY (ARRAY['kb'::text, 'widget'::text, 'api'::text, 'admin'::text])))
);


--
-- Name: search_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.search_events ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.search_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: search_index; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.search_index (
    version_id bigint NOT NULL,
    article_id bigint NOT NULL,
    language text NOT NULL,
    code text NOT NULL,
    title text NOT NULL,
    subtitle text DEFAULT ''::text NOT NULL,
    keywords text DEFAULT ''::text NOT NULL,
    body text DEFAULT ''::text NOT NULL,
    document tsvector GENERATED ALWAYS AS ((((setweight(to_tsvector('english'::regconfig, title), 'A'::"char") || setweight(to_tsvector('english'::regconfig, keywords), 'A'::"char")) || setweight(to_tsvector('english'::regconfig, subtitle), 'B'::"char")) || setweight(to_tsvector('english'::regconfig, body), 'C'::"char"))) STORED,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: sessions; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.sessions (
    id bigint NOT NULL,
    user_id bigint NOT NULL,
    ip_address character varying,
    user_agent character varying,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL
);


--
-- Name: sessions_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.sessions_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: sessions_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.sessions_id_seq OWNED BY public.sessions.id;


--
-- Name: settings; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.settings (
    key text NOT NULL,
    value jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: slug_redirects; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.slug_redirects (
    from_path text NOT NULL,
    article_id bigint,
    category_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT slug_redirects_check CHECK ((num_nonnulls(article_id, category_id) = 1))
);


--
-- Name: tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.tags (
    id bigint NOT NULL,
    name public.citext NOT NULL
);


--
-- Name: tags_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.tags ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.tags_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: team_members; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.team_members (
    team_id bigint NOT NULL,
    user_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: teams; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.teams (
    id bigint NOT NULL,
    name public.citext NOT NULL,
    assignment text DEFAULT 'manual'::text NOT NULL,
    assignment_limit integer,
    rr_cursor_user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT teams_assignment_check CHECK ((assignment = ANY (ARRAY['manual'::text, 'round_robin'::text, 'balanced'::text]))),
    CONSTRAINT teams_assignment_limit_check CHECK (((assignment_limit IS NULL) OR (assignment_limit > 0)))
);


--
-- Name: teams_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.teams ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.teams_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: thread_links; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thread_links (
    from_thread_id bigint NOT NULL,
    to_thread_id bigint NOT NULL,
    kind text NOT NULL,
    created_by_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT thread_links_check CHECK ((from_thread_id <> to_thread_id)),
    CONSTRAINT thread_links_kind_check CHECK ((kind = ANY (ARRAY['handoff'::text, 'tracker'::text])))
);


--
-- Name: threads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.threads (
    id bigint NOT NULL,
    kind text DEFAULT 'conversation'::text NOT NULL,
    number bigint NOT NULL,
    contact_id bigint,
    channel text NOT NULL,
    title text DEFAULT ''::text NOT NULL,
    state text DEFAULT 'open'::text NOT NULL,
    priority text DEFAULT 'none'::text NOT NULL,
    assignee_user_id bigint,
    assignee_team_id bigint,
    snoozed_until timestamp with time zone,
    waiting_since timestamp with time zone,
    page_context text,
    search_query text,
    reply_token text NOT NULL,
    first_response_at timestamp with time zone,
    closed_at timestamp with time zone,
    rating smallint,
    rating_comment text,
    ticket_type_id bigint,
    ticket_state_id bigint,
    ticket_attributes jsonb,
    is_shared boolean,
    purge_after timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT threads_channel_check CHECK ((channel = ANY (ARRAY['widget'::text, 'email'::text, 'api'::text, 'internal'::text]))),
    CONSTRAINT threads_check CHECK (((state <> 'snoozed'::text) OR (snoozed_until IS NOT NULL))),
    CONSTRAINT threads_check1 CHECK (((state <> 'closed'::text) OR (closed_at IS NOT NULL))),
    CONSTRAINT threads_check2 CHECK (((kind = 'ticket'::text) OR (num_nonnulls(ticket_type_id, ticket_state_id, ticket_attributes, is_shared) = 0))),
    CONSTRAINT threads_check3 CHECK (((kind = 'conversation'::text) OR (num_nonnulls(ticket_type_id, ticket_state_id, ticket_attributes, is_shared) = 4))),
    CONSTRAINT threads_kind_check CHECK ((kind = ANY (ARRAY['conversation'::text, 'ticket'::text]))),
    CONSTRAINT threads_priority_check CHECK ((priority = ANY (ARRAY['none'::text, 'low'::text, 'medium'::text, 'high'::text, 'urgent'::text]))),
    CONSTRAINT threads_rating_check CHECK (((rating >= 1) AND (rating <= 5))),
    CONSTRAINT threads_state_check CHECK ((state = ANY (ARRAY['open'::text, 'snoozed'::text, 'closed'::text])))
);


--
-- Name: thread_number_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.thread_number_seq
    START WITH 1001
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: thread_number_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.thread_number_seq OWNED BY public.threads.number;


--
-- Name: thread_parts; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thread_parts (
    id bigint NOT NULL,
    thread_id bigint NOT NULL,
    author_type text NOT NULL,
    author_user_id bigint,
    author_contact_id bigint,
    kind text NOT NULL,
    body text DEFAULT ''::text NOT NULL,
    event jsonb,
    channel text DEFAULT 'widget'::text NOT NULL,
    email_message_id text,
    client_id text,
    edited_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    search tsvector GENERATED ALWAYS AS (to_tsvector('english'::regconfig, body)) STORED,
    CONSTRAINT thread_parts_author_type_check CHECK ((author_type = ANY (ARRAY['contact'::text, 'user'::text, 'system'::text]))),
    CONSTRAINT thread_parts_channel_check CHECK ((channel = ANY (ARRAY['widget'::text, 'email'::text, 'api'::text, 'admin'::text, 'system'::text]))),
    CONSTRAINT thread_parts_check CHECK (((author_type <> 'contact'::text) OR (kind = ANY (ARRAY['comment'::text, 'rating'::text])))),
    CONSTRAINT thread_parts_kind_check CHECK ((kind = ANY (ARRAY['comment'::text, 'note'::text, 'assignment'::text, 'state_change'::text, 'ticket_state_change'::text, 'priority'::text, 'snooze'::text, 'close'::text, 'open'::text, 'rating'::text, 'article'::text, 'link'::text, 'attribute_change'::text])))
);


--
-- Name: thread_parts_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.thread_parts ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.thread_parts_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: thread_reads; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thread_reads (
    thread_id bigint NOT NULL,
    user_id bigint NOT NULL,
    last_part_id bigint NOT NULL,
    read_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: thread_tags; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.thread_tags (
    thread_id bigint NOT NULL,
    tag_id bigint NOT NULL
);


--
-- Name: threads_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.threads ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.threads_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ticket_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ticket_states (
    id bigint NOT NULL,
    category text NOT NULL,
    internal_label text NOT NULL,
    external_label text NOT NULL,
    notify_customer boolean DEFAULT true NOT NULL,
    archived_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT ticket_states_category_check CHECK ((category = ANY (ARRAY['submitted'::text, 'in_progress'::text, 'waiting_on_customer'::text, 'resolved'::text])))
);


--
-- Name: ticket_states_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.ticket_states ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.ticket_states_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ticket_type_attributes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ticket_type_attributes (
    id bigint NOT NULL,
    ticket_type_id bigint NOT NULL,
    key text NOT NULL,
    label text NOT NULL,
    data_type text NOT NULL,
    options jsonb DEFAULT '[]'::jsonb NOT NULL,
    required_for_agents boolean DEFAULT false NOT NULL,
    required_for_contacts boolean DEFAULT false NOT NULL,
    visible_to_contacts boolean DEFAULT false NOT NULL,
    "position" integer DEFAULT 0 NOT NULL,
    archived_at timestamp with time zone,
    multiline boolean DEFAULT false NOT NULL,
    required_to_close boolean DEFAULT false NOT NULL,
    hidden_on_create boolean DEFAULT false NOT NULL,
    CONSTRAINT ticket_type_attributes_check CHECK (((NOT required_for_contacts) OR visible_to_contacts)),
    CONSTRAINT ticket_type_attributes_data_type_check CHECK ((data_type = ANY (ARRAY['string'::text, 'list'::text, 'integer'::text, 'decimal'::text, 'boolean'::text, 'datetime'::text, 'files'::text]))),
    CONSTRAINT ticket_type_attributes_key_check CHECK ((key ~ '^[a-z][a-z0-9_]{0,62}$'::text))
);


--
-- Name: ticket_type_attributes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.ticket_type_attributes ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.ticket_type_attributes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: ticket_type_states; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ticket_type_states (
    ticket_type_id bigint NOT NULL,
    state_id bigint NOT NULL,
    "position" integer DEFAULT 0 NOT NULL
);


--
-- Name: ticket_types; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ticket_types (
    id bigint NOT NULL,
    name text NOT NULL,
    description text DEFAULT ''::text NOT NULL,
    category text NOT NULL,
    icon text DEFAULT 'file'::text NOT NULL,
    shareable boolean DEFAULT false NOT NULL,
    default_team_id bigint,
    archived_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    description_visible boolean DEFAULT true NOT NULL,
    description_required boolean DEFAULT false NOT NULL,
    CONSTRAINT ticket_types_category_check CHECK ((category = ANY (ARRAY['customer'::text, 'back_office'::text, 'tracker'::text]))),
    CONSTRAINT ticket_types_check CHECK (((category <> 'tracker'::text) OR (NOT shareable)))
);


--
-- Name: ticket_types_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.ticket_types ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.ticket_types_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    email_address character varying NOT NULL,
    password_digest character varying NOT NULL,
    created_at timestamp(6) without time zone NOT NULL,
    updated_at timestamp(6) without time zone NOT NULL,
    first_name character varying DEFAULT ''::character varying NOT NULL,
    last_name character varying DEFAULT ''::character varying NOT NULL,
    role character varying DEFAULT 'viewer'::character varying NOT NULL,
    active boolean DEFAULT true NOT NULL,
    failed_logins integer DEFAULT 0 NOT NULL,
    locked_until timestamp(6) without time zone,
    last_sign_in_at timestamp(6) without time zone,
    availability text DEFAULT 'active'::text NOT NULL,
    permissions text[] DEFAULT '{}'::text[] NOT NULL,
    last_active_at timestamp with time zone,
    CONSTRAINT users_availability_check CHECK ((availability = ANY (ARRAY['active'::text, 'away'::text]))),
    CONSTRAINT users_role_check CHECK (((role)::text = ANY ((ARRAY['superadmin'::character varying, 'admin'::character varying, 'collaborator'::character varying, 'draft_writer'::character varying, 'viewer'::character varying])::text[])))
);


--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: view_events; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.view_events (
    id bigint NOT NULL,
    article_id bigint NOT NULL,
    version_id bigint,
    search_event_id bigint,
    source text NOT NULL,
    page_context text,
    seconds_spent integer DEFAULT 0 NOT NULL,
    read boolean DEFAULT false NOT NULL,
    visitor_hash text,
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT view_events_source_check CHECK ((source = ANY (ARRAY['kb'::text, 'widget'::text, 'embed'::text, 'api'::text])))
);


--
-- Name: view_events_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.view_events ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.view_events_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: votes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.votes (
    id bigint NOT NULL,
    article_id bigint NOT NULL,
    value smallint NOT NULL,
    comment text DEFAULT ''::text NOT NULL,
    source text NOT NULL,
    visitor_hash text NOT NULL,
    user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT votes_source_check CHECK ((source = ANY (ARRAY['kb'::text, 'widget'::text, 'embed'::text, 'api'::text]))),
    CONSTRAINT votes_value_check CHECK ((value = ANY (ARRAY['-1'::integer, 1])))
);


--
-- Name: votes_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.votes ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.votes_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: webhook_deliveries; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhook_deliveries (
    id bigint NOT NULL,
    webhook_id bigint NOT NULL,
    activity_id bigint NOT NULL,
    attempt integer DEFAULT 0 NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    response_code integer,
    error text,
    next_attempt_at timestamp with time zone DEFAULT now() NOT NULL,
    delivered_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT webhook_deliveries_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'delivered'::text, 'failed'::text, 'dead'::text])))
);


--
-- Name: webhook_deliveries_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.webhook_deliveries ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.webhook_deliveries_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: webhooks; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.webhooks (
    id bigint NOT NULL,
    url text NOT NULL,
    event text NOT NULL,
    secret text NOT NULL,
    enabled boolean DEFAULT true NOT NULL,
    last_response_code integer,
    created_by_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT webhooks_event_check CHECK ((event = ANY (ARRAY['user_create'::text, 'user_update'::text, 'user_delete'::text, 'question_create'::text, 'question_update'::text, 'question_delete'::text, 'question_archive'::text, 'question_publish'::text, 'comment_create'::text, 'comment_update'::text, 'comment_delete'::text, 'category_create'::text, 'category_update'::text, 'category_delete'::text])))
);


--
-- Name: webhooks_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.webhooks ALTER COLUMN id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.webhooks_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: action_mailbox_inbound_emails id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_mailbox_inbound_emails ALTER COLUMN id SET DEFAULT nextval('public.action_mailbox_inbound_emails_id_seq'::regclass);


--
-- Name: action_text_rich_texts id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_text_rich_texts ALTER COLUMN id SET DEFAULT nextval('public.action_text_rich_texts_id_seq'::regclass);


--
-- Name: active_storage_attachments id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments ALTER COLUMN id SET DEFAULT nextval('public.active_storage_attachments_id_seq'::regclass);


--
-- Name: active_storage_blobs id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs ALTER COLUMN id SET DEFAULT nextval('public.active_storage_blobs_id_seq'::regclass);


--
-- Name: active_storage_variant_records id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records ALTER COLUMN id SET DEFAULT nextval('public.active_storage_variant_records_id_seq'::regclass);


--
-- Name: sessions id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions ALTER COLUMN id SET DEFAULT nextval('public.sessions_id_seq'::regclass);


--
-- Name: threads number; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads ALTER COLUMN number SET DEFAULT nextval('public.thread_number_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: action_mailbox_inbound_emails action_mailbox_inbound_emails_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_mailbox_inbound_emails
    ADD CONSTRAINT action_mailbox_inbound_emails_pkey PRIMARY KEY (id);


--
-- Name: action_text_rich_texts action_text_rich_texts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.action_text_rich_texts
    ADD CONSTRAINT action_text_rich_texts_pkey PRIMARY KEY (id);


--
-- Name: active_storage_attachments active_storage_attachments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT active_storage_attachments_pkey PRIMARY KEY (id);


--
-- Name: active_storage_blobs active_storage_blobs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_blobs
    ADD CONSTRAINT active_storage_blobs_pkey PRIMARY KEY (id);


--
-- Name: active_storage_variant_records active_storage_variant_records_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT active_storage_variant_records_pkey PRIMARY KEY (id);


--
-- Name: activities activities_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_pkey PRIMARY KEY (id);


--
-- Name: api_keys api_keys_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_pkey PRIMARY KEY (id);


--
-- Name: api_keys api_keys_token_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_token_hash_key UNIQUE (token_hash);


--
-- Name: ar_internal_metadata ar_internal_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ar_internal_metadata
    ADD CONSTRAINT ar_internal_metadata_pkey PRIMARY KEY (key);


--
-- Name: article_access article_access_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_access
    ADD CONSTRAINT article_access_pkey PRIMARY KEY (id);


--
-- Name: article_categories article_categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_categories
    ADD CONSTRAINT article_categories_pkey PRIMARY KEY (article_id, category_id);


--
-- Name: article_keywords article_keywords_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_keywords
    ADD CONSTRAINT article_keywords_pkey PRIMARY KEY (article_id, keyword_id);


--
-- Name: article_versions article_versions_article_id_language_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_versions
    ADD CONSTRAINT article_versions_article_id_language_number_key UNIQUE (article_id, language, number);


--
-- Name: article_versions article_versions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_versions
    ADD CONSTRAINT article_versions_pkey PRIMARY KEY (id);


--
-- Name: articles articles_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_code_key UNIQUE (code);


--
-- Name: articles articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_pkey PRIMARY KEY (id);


--
-- Name: articles articles_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_slug_key UNIQUE (slug);


--
-- Name: audit_events audit_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.audit_events
    ADD CONSTRAINT audit_events_pkey PRIMARY KEY (id);


--
-- Name: categories categories_code_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_code_key UNIQUE (code);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: categories categories_slug_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_slug_key UNIQUE (slug);


--
-- Name: category_access category_access_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_access
    ADD CONSTRAINT category_access_pkey PRIMARY KEY (id);


--
-- Name: comments comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_pkey PRIMARY KEY (id);


--
-- Name: companies companies_external_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_external_id_key UNIQUE (external_id);


--
-- Name: companies companies_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.companies
    ADD CONSTRAINT companies_pkey PRIMARY KEY (id);


--
-- Name: contact_requests contact_requests_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_requests
    ADD CONSTRAINT contact_requests_pkey PRIMARY KEY (id);


--
-- Name: contacts contacts_external_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_external_id_key UNIQUE (external_id);


--
-- Name: contacts contacts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_pkey PRIMARY KEY (id);


--
-- Name: context_rule_articles context_rule_articles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.context_rule_articles
    ADD CONSTRAINT context_rule_articles_pkey PRIMARY KEY (rule_id, article_id);


--
-- Name: context_rules context_rules_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.context_rules
    ADD CONSTRAINT context_rules_pkey PRIMARY KEY (id);


--
-- Name: group_members group_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_pkey PRIMARY KEY (group_id, user_id);


--
-- Name: groups groups_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_name_key UNIQUE (name);


--
-- Name: groups groups_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.groups
    ADD CONSTRAINT groups_pkey PRIMARY KEY (id);


--
-- Name: import_map import_map_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_map
    ADD CONSTRAINT import_map_pkey PRIMARY KEY (source, source_type, source_id);


--
-- Name: import_runs import_runs_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_runs
    ADD CONSTRAINT import_runs_pkey PRIMARY KEY (id);


--
-- Name: keywords keywords_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.keywords
    ADD CONSTRAINT keywords_name_key UNIQUE (name);


--
-- Name: keywords keywords_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.keywords
    ADD CONSTRAINT keywords_pkey PRIMARY KEY (id);


--
-- Name: macros macros_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.macros
    ADD CONSTRAINT macros_pkey PRIMARY KEY (id);


--
-- Name: mentions mentions_part_id_user_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mentions
    ADD CONSTRAINT mentions_part_id_user_id_key UNIQUE (part_id, user_id);


--
-- Name: mentions mentions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mentions
    ADD CONSTRAINT mentions_pkey PRIMARY KEY (id);


--
-- Name: notifications notifications_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_pkey PRIMARY KEY (id);


--
-- Name: revisions revisions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revisions
    ADD CONSTRAINT revisions_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: search_events search_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_events
    ADD CONSTRAINT search_events_pkey PRIMARY KEY (id);


--
-- Name: search_index search_index_article_id_language_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_index
    ADD CONSTRAINT search_index_article_id_language_key UNIQUE (article_id, language);


--
-- Name: search_index search_index_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_index
    ADD CONSTRAINT search_index_pkey PRIMARY KEY (version_id);


--
-- Name: sessions sessions_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT sessions_pkey PRIMARY KEY (id);


--
-- Name: settings settings_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.settings
    ADD CONSTRAINT settings_pkey PRIMARY KEY (key);


--
-- Name: slug_redirects slug_redirects_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.slug_redirects
    ADD CONSTRAINT slug_redirects_pkey PRIMARY KEY (from_path);


--
-- Name: tags tags_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_name_key UNIQUE (name);


--
-- Name: tags tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.tags
    ADD CONSTRAINT tags_pkey PRIMARY KEY (id);


--
-- Name: team_members team_members_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_pkey PRIMARY KEY (team_id, user_id);


--
-- Name: teams teams_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_name_key UNIQUE (name);


--
-- Name: teams teams_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_pkey PRIMARY KEY (id);


--
-- Name: thread_links thread_links_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_links
    ADD CONSTRAINT thread_links_pkey PRIMARY KEY (from_thread_id, to_thread_id);


--
-- Name: thread_parts thread_parts_email_message_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_parts
    ADD CONSTRAINT thread_parts_email_message_id_key UNIQUE (email_message_id);


--
-- Name: thread_parts thread_parts_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_parts
    ADD CONSTRAINT thread_parts_pkey PRIMARY KEY (id);


--
-- Name: thread_reads thread_reads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_reads
    ADD CONSTRAINT thread_reads_pkey PRIMARY KEY (thread_id, user_id);


--
-- Name: thread_tags thread_tags_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_tags
    ADD CONSTRAINT thread_tags_pkey PRIMARY KEY (thread_id, tag_id);


--
-- Name: threads threads_number_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads
    ADD CONSTRAINT threads_number_key UNIQUE (number);


--
-- Name: threads threads_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads
    ADD CONSTRAINT threads_pkey PRIMARY KEY (id);


--
-- Name: threads threads_reply_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads
    ADD CONSTRAINT threads_reply_token_key UNIQUE (reply_token);


--
-- Name: ticket_states ticket_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_states
    ADD CONSTRAINT ticket_states_pkey PRIMARY KEY (id);


--
-- Name: ticket_type_attributes ticket_type_attributes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_type_attributes
    ADD CONSTRAINT ticket_type_attributes_pkey PRIMARY KEY (id);


--
-- Name: ticket_type_attributes ticket_type_attributes_ticket_type_id_key_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_type_attributes
    ADD CONSTRAINT ticket_type_attributes_ticket_type_id_key_key UNIQUE (ticket_type_id, key);


--
-- Name: ticket_type_states ticket_type_states_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_type_states
    ADD CONSTRAINT ticket_type_states_pkey PRIMARY KEY (ticket_type_id, state_id);


--
-- Name: ticket_types ticket_types_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_types
    ADD CONSTRAINT ticket_types_pkey PRIMARY KEY (id);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: view_events view_events_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.view_events
    ADD CONSTRAINT view_events_pkey PRIMARY KEY (id);


--
-- Name: votes votes_article_id_visitor_hash_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_article_id_visitor_hash_key UNIQUE (article_id, visitor_hash);


--
-- Name: votes votes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_pkey PRIMARY KEY (id);


--
-- Name: webhook_deliveries webhook_deliveries_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_deliveries
    ADD CONSTRAINT webhook_deliveries_pkey PRIMARY KEY (id);


--
-- Name: webhook_deliveries webhook_deliveries_webhook_id_activity_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_deliveries
    ADD CONSTRAINT webhook_deliveries_webhook_id_activity_id_key UNIQUE (webhook_id, activity_id);


--
-- Name: webhooks webhooks_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhooks
    ADD CONSTRAINT webhooks_pkey PRIMARY KEY (id);


--
-- Name: activities_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_created ON public.activities USING btree (created_at);


--
-- Name: activities_owner; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_owner ON public.activities USING btree (owner_id, created_at);


--
-- Name: activities_trackable; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activities_trackable ON public.activities USING btree (trackable_type, trackable_id, created_at);


--
-- Name: api_keys_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX api_keys_created_by ON public.api_keys USING btree (created_by_id);


--
-- Name: article_access_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX article_access_group ON public.article_access USING btree (group_id);


--
-- Name: article_access_group_u; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX article_access_group_u ON public.article_access USING btree (article_id, group_id) WHERE (group_id IS NOT NULL);


--
-- Name: article_access_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX article_access_user ON public.article_access USING btree (user_id);


--
-- Name: article_access_user_u; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX article_access_user_u ON public.article_access USING btree (article_id, user_id) WHERE (user_id IS NOT NULL);


--
-- Name: article_categories_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX article_categories_category ON public.article_categories USING btree (category_id, "position");


--
-- Name: article_keywords_keyword; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX article_keywords_keyword ON public.article_keywords USING btree (keyword_id);


--
-- Name: article_versions_article; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX article_versions_article ON public.article_versions USING btree (article_id, status);


--
-- Name: article_versions_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX article_versions_created_by ON public.article_versions USING btree (created_by_id);


--
-- Name: article_versions_current_revision; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX article_versions_current_revision ON public.article_versions USING btree (current_revision_id);


--
-- Name: article_versions_expire_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX article_versions_expire_at ON public.article_versions USING btree (expire_at) WHERE ((expire_at IS NOT NULL) AND (status = 'published'::text));


--
-- Name: article_versions_one_default; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX article_versions_one_default ON public.article_versions USING btree (article_id, language) WHERE is_default;


--
-- Name: article_versions_publish_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX article_versions_publish_at ON public.article_versions USING btree (publish_at) WHERE ((publish_at IS NOT NULL) AND (status = 'draft'::text));


--
-- Name: articles_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX articles_created_by ON public.articles USING btree (created_by_id);


--
-- Name: articles_main_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX articles_main_category ON public.articles USING btree (main_category_id);


--
-- Name: articles_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX articles_updated ON public.articles USING btree (updated_at);


--
-- Name: audit_events_actor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_events_actor ON public.audit_events USING btree (actor_type, actor_id, at);


--
-- Name: audit_events_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_events_at ON public.audit_events USING brin (at);


--
-- Name: audit_events_subject; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX audit_events_subject ON public.audit_events USING btree (subject_type, subject_id, at);


--
-- Name: categories_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX categories_parent ON public.categories USING btree (parent_id, "position");


--
-- Name: category_access_group; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX category_access_group ON public.category_access USING btree (group_id);


--
-- Name: category_access_group_u; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX category_access_group_u ON public.category_access USING btree (category_id, group_id) WHERE (group_id IS NOT NULL);


--
-- Name: category_access_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX category_access_user ON public.category_access USING btree (user_id);


--
-- Name: category_access_user_u; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX category_access_user_u ON public.category_access USING btree (category_id, user_id) WHERE (user_id IS NOT NULL);


--
-- Name: comments_author; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_author ON public.comments USING btree (author_id);


--
-- Name: comments_parent; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_parent ON public.comments USING btree (parent_id);


--
-- Name: comments_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX comments_version ON public.comments USING btree (version_id, resolved_at);


--
-- Name: contact_requests_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_requests_created ON public.contact_requests USING btree (created_at);


--
-- Name: contact_requests_search; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contact_requests_search ON public.contact_requests USING btree (search_event_id);


--
-- Name: contacts_company; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contacts_company ON public.contacts USING btree (company_id);


--
-- Name: contacts_email; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX contacts_email ON public.contacts USING btree (email) WHERE ((email IS NOT NULL) AND (deleted_at IS NULL));


--
-- Name: contacts_name_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX contacts_name_trgm ON public.contacts USING gin (name public.gin_trgm_ops);


--
-- Name: context_rule_articles_article; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX context_rule_articles_article ON public.context_rule_articles USING btree (article_id);


--
-- Name: context_rules_priority; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX context_rules_priority ON public.context_rules USING btree (priority DESC);


--
-- Name: group_members_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX group_members_user ON public.group_members USING btree (user_id);


--
-- Name: import_map_run; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX import_map_run ON public.import_map USING btree (run_id);


--
-- Name: import_runs_started_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX import_runs_started_by ON public.import_runs USING btree (started_by_id);


--
-- Name: index_action_mailbox_inbound_emails_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_action_mailbox_inbound_emails_uniqueness ON public.action_mailbox_inbound_emails USING btree (message_id, message_checksum);


--
-- Name: index_action_text_rich_texts_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_action_text_rich_texts_uniqueness ON public.action_text_rich_texts USING btree (record_type, record_id, name);


--
-- Name: index_active_storage_attachments_on_blob_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_active_storage_attachments_on_blob_id ON public.active_storage_attachments USING btree (blob_id);


--
-- Name: index_active_storage_attachments_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_attachments_uniqueness ON public.active_storage_attachments USING btree (record_type, record_id, name, blob_id);


--
-- Name: index_active_storage_blobs_on_key; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_blobs_on_key ON public.active_storage_blobs USING btree (key);


--
-- Name: index_active_storage_variant_records_uniqueness; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_active_storage_variant_records_uniqueness ON public.active_storage_variant_records USING btree (blob_id, variation_digest);


--
-- Name: index_sessions_on_user_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX index_sessions_on_user_id ON public.sessions USING btree (user_id);


--
-- Name: index_users_on_email_address; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX index_users_on_email_address ON public.users USING btree (email_address);


--
-- Name: macros_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX macros_created_by ON public.macros USING btree (created_by_id);


--
-- Name: macros_team; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX macros_team ON public.macros USING btree (team_id);


--
-- Name: mentions_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX mentions_user ON public.mentions USING btree (user_id, read_at);


--
-- Name: notifications_thread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_thread ON public.notifications USING btree (thread_id);


--
-- Name: notifications_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX notifications_user ON public.notifications USING btree (user_id, read_at, created_at);


--
-- Name: revisions_author; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX revisions_author ON public.revisions USING btree (author_id);


--
-- Name: revisions_base; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX revisions_base ON public.revisions USING btree (base_revision_id);


--
-- Name: revisions_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX revisions_version ON public.revisions USING btree (version_id, created_at);


--
-- Name: search_events_clicked; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_events_clicked ON public.search_events USING btree (clicked_article_id);


--
-- Name: search_events_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_events_created ON public.search_events USING btree (created_at);


--
-- Name: search_events_normalized; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_events_normalized ON public.search_events USING btree (normalized, created_at);


--
-- Name: search_events_outcome; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_events_outcome ON public.search_events USING btree (outcome, created_at);


--
-- Name: search_events_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_events_user ON public.search_events USING btree (user_id);


--
-- Name: search_index_code; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_index_code ON public.search_index USING btree (code);


--
-- Name: search_index_document; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_index_document ON public.search_index USING gin (document);


--
-- Name: search_index_trgm; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX search_index_trgm ON public.search_index USING gin ((((title || ' '::text) || keywords)) public.gin_trgm_ops);


--
-- Name: slug_redirects_article; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX slug_redirects_article ON public.slug_redirects USING btree (article_id);


--
-- Name: slug_redirects_category; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX slug_redirects_category ON public.slug_redirects USING btree (category_id);


--
-- Name: team_members_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX team_members_user ON public.team_members USING btree (user_id);


--
-- Name: teams_rr_cursor; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX teams_rr_cursor ON public.teams USING btree (rr_cursor_user_id);


--
-- Name: thread_links_to; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX thread_links_to ON public.thread_links USING btree (to_thread_id);


--
-- Name: thread_parts_author_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX thread_parts_author_contact ON public.thread_parts USING btree (author_contact_id);


--
-- Name: thread_parts_author_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX thread_parts_author_user ON public.thread_parts USING btree (author_user_id);


--
-- Name: thread_parts_client_id; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX thread_parts_client_id ON public.thread_parts USING btree (thread_id, client_id) WHERE (client_id IS NOT NULL);


--
-- Name: thread_parts_search; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX thread_parts_search ON public.thread_parts USING gin (search) WHERE (kind = ANY (ARRAY['comment'::text, 'note'::text]));


--
-- Name: thread_parts_thread; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX thread_parts_thread ON public.thread_parts USING btree (thread_id, id);


--
-- Name: thread_reads_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX thread_reads_user ON public.thread_reads USING btree (user_id);


--
-- Name: thread_tags_tag; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX thread_tags_tag ON public.thread_tags USING btree (tag_id);


--
-- Name: threads_contact; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX threads_contact ON public.threads USING btree (contact_id, created_at);


--
-- Name: threads_open_team; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX threads_open_team ON public.threads USING btree (assignee_team_id, state, waiting_since);


--
-- Name: threads_open_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX threads_open_user ON public.threads USING btree (assignee_user_id, state, waiting_since);


--
-- Name: threads_purge; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX threads_purge ON public.threads USING btree (purge_after) WHERE (purge_after IS NOT NULL);


--
-- Name: threads_snoozed; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX threads_snoozed ON public.threads USING btree (snoozed_until) WHERE (state = 'snoozed'::text);


--
-- Name: threads_ticket_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX threads_ticket_state ON public.threads USING btree (ticket_state_id);


--
-- Name: threads_ticket_type; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX threads_ticket_type ON public.threads USING btree (ticket_type_id, ticket_state_id) WHERE (kind = 'ticket'::text);


--
-- Name: threads_unassigned; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX threads_unassigned ON public.threads USING btree (created_at) WHERE ((assignee_user_id IS NULL) AND (state = 'open'::text));


--
-- Name: threads_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX threads_updated ON public.threads USING btree (updated_at);


--
-- Name: ticket_type_states_state; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ticket_type_states_state ON public.ticket_type_states USING btree (state_id);


--
-- Name: ticket_types_default_team; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ticket_types_default_team ON public.ticket_types USING btree (default_team_id);


--
-- Name: view_events_article; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX view_events_article ON public.view_events USING btree (article_id, created_at);


--
-- Name: view_events_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX view_events_created ON public.view_events USING btree (created_at);


--
-- Name: view_events_search; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX view_events_search ON public.view_events USING btree (search_event_id);


--
-- Name: view_events_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX view_events_user ON public.view_events USING btree (user_id);


--
-- Name: view_events_version; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX view_events_version ON public.view_events USING btree (version_id);


--
-- Name: votes_article; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX votes_article ON public.votes USING btree (article_id, created_at);


--
-- Name: votes_user; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX votes_user ON public.votes USING btree (user_id);


--
-- Name: webhook_deliveries_activity; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX webhook_deliveries_activity ON public.webhook_deliveries USING btree (activity_id);


--
-- Name: webhook_deliveries_due; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX webhook_deliveries_due ON public.webhook_deliveries USING btree (next_attempt_at) WHERE (status = ANY (ARRAY['pending'::text, 'failed'::text]));


--
-- Name: webhooks_created_by; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX webhooks_created_by ON public.webhooks USING btree (created_by_id);


--
-- Name: webhooks_event; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX webhooks_event ON public.webhooks USING btree (event) WHERE enabled;


--
-- Name: audit_events audit_events_no_early_delete; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_events_no_early_delete BEFORE DELETE ON public.audit_events FOR EACH ROW EXECUTE FUNCTION public.audit_events_guard();


--
-- Name: audit_events audit_events_no_update; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER audit_events_no_update BEFORE UPDATE ON public.audit_events FOR EACH ROW EXECUTE FUNCTION public.audit_events_guard();


--
-- Name: activities activities_owner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activities
    ADD CONSTRAINT activities_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: api_keys api_keys_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.api_keys
    ADD CONSTRAINT api_keys_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: article_access article_access_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_access
    ADD CONSTRAINT article_access_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: article_access article_access_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_access
    ADD CONSTRAINT article_access_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: article_access article_access_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_access
    ADD CONSTRAINT article_access_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: article_categories article_categories_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_categories
    ADD CONSTRAINT article_categories_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: article_categories article_categories_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_categories
    ADD CONSTRAINT article_categories_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- Name: article_keywords article_keywords_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_keywords
    ADD CONSTRAINT article_keywords_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: article_keywords article_keywords_keyword_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_keywords
    ADD CONSTRAINT article_keywords_keyword_id_fkey FOREIGN KEY (keyword_id) REFERENCES public.keywords(id) ON DELETE CASCADE;


--
-- Name: article_versions article_versions_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_versions
    ADD CONSTRAINT article_versions_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: article_versions article_versions_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_versions
    ADD CONSTRAINT article_versions_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: article_versions article_versions_current_revision; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.article_versions
    ADD CONSTRAINT article_versions_current_revision FOREIGN KEY (current_revision_id) REFERENCES public.revisions(id) ON DELETE SET NULL;


--
-- Name: articles articles_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: articles articles_main_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.articles
    ADD CONSTRAINT articles_main_category_id_fkey FOREIGN KEY (main_category_id) REFERENCES public.categories(id) ON DELETE RESTRICT;


--
-- Name: categories categories_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.categories(id) ON DELETE RESTRICT;


--
-- Name: category_access category_access_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_access
    ADD CONSTRAINT category_access_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- Name: category_access category_access_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_access
    ADD CONSTRAINT category_access_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: category_access category_access_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.category_access
    ADD CONSTRAINT category_access_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: comments comments_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: comments comments_parent_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_parent_id_fkey FOREIGN KEY (parent_id) REFERENCES public.comments(id) ON DELETE CASCADE;


--
-- Name: comments comments_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.comments
    ADD CONSTRAINT comments_version_id_fkey FOREIGN KEY (version_id) REFERENCES public.article_versions(id) ON DELETE CASCADE;


--
-- Name: contact_requests contact_requests_search_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contact_requests
    ADD CONSTRAINT contact_requests_search_event_id_fkey FOREIGN KEY (search_event_id) REFERENCES public.search_events(id) ON DELETE SET NULL;


--
-- Name: contacts contacts_company_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.contacts
    ADD CONSTRAINT contacts_company_id_fkey FOREIGN KEY (company_id) REFERENCES public.companies(id) ON DELETE SET NULL;


--
-- Name: context_rule_articles context_rule_articles_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.context_rule_articles
    ADD CONSTRAINT context_rule_articles_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: context_rule_articles context_rule_articles_rule_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.context_rule_articles
    ADD CONSTRAINT context_rule_articles_rule_id_fkey FOREIGN KEY (rule_id) REFERENCES public.context_rules(id) ON DELETE CASCADE;


--
-- Name: sessions fk_rails_758836b4f0; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.sessions
    ADD CONSTRAINT fk_rails_758836b4f0 FOREIGN KEY (user_id) REFERENCES public.users(id);


--
-- Name: active_storage_variant_records fk_rails_993965df05; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_variant_records
    ADD CONSTRAINT fk_rails_993965df05 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: active_storage_attachments fk_rails_c3b3935057; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_storage_attachments
    ADD CONSTRAINT fk_rails_c3b3935057 FOREIGN KEY (blob_id) REFERENCES public.active_storage_blobs(id);


--
-- Name: group_members group_members_group_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_group_id_fkey FOREIGN KEY (group_id) REFERENCES public.groups(id) ON DELETE CASCADE;


--
-- Name: group_members group_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.group_members
    ADD CONSTRAINT group_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: import_map import_map_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_map
    ADD CONSTRAINT import_map_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.import_runs(id) ON DELETE SET NULL;


--
-- Name: import_runs import_runs_started_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.import_runs
    ADD CONSTRAINT import_runs_started_by_id_fkey FOREIGN KEY (started_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: macros macros_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.macros
    ADD CONSTRAINT macros_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: macros macros_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.macros
    ADD CONSTRAINT macros_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: mentions mentions_part_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mentions
    ADD CONSTRAINT mentions_part_id_fkey FOREIGN KEY (part_id) REFERENCES public.thread_parts(id) ON DELETE CASCADE;


--
-- Name: mentions mentions_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.mentions
    ADD CONSTRAINT mentions_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.threads(id) ON DELETE CASCADE;


--
-- Name: notifications notifications_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.notifications
    ADD CONSTRAINT notifications_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: revisions revisions_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revisions
    ADD CONSTRAINT revisions_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: revisions revisions_base_revision_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revisions
    ADD CONSTRAINT revisions_base_revision_id_fkey FOREIGN KEY (base_revision_id) REFERENCES public.revisions(id) ON DELETE SET NULL;


--
-- Name: revisions revisions_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.revisions
    ADD CONSTRAINT revisions_version_id_fkey FOREIGN KEY (version_id) REFERENCES public.article_versions(id) ON DELETE CASCADE;


--
-- Name: search_events search_events_clicked_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_events
    ADD CONSTRAINT search_events_clicked_article_id_fkey FOREIGN KEY (clicked_article_id) REFERENCES public.articles(id) ON DELETE SET NULL;


--
-- Name: search_events search_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_events
    ADD CONSTRAINT search_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: search_index search_index_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_index
    ADD CONSTRAINT search_index_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: search_index search_index_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.search_index
    ADD CONSTRAINT search_index_version_id_fkey FOREIGN KEY (version_id) REFERENCES public.article_versions(id) ON DELETE CASCADE;


--
-- Name: slug_redirects slug_redirects_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.slug_redirects
    ADD CONSTRAINT slug_redirects_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: slug_redirects slug_redirects_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.slug_redirects
    ADD CONSTRAINT slug_redirects_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE CASCADE;


--
-- Name: team_members team_members_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_team_id_fkey FOREIGN KEY (team_id) REFERENCES public.teams(id) ON DELETE CASCADE;


--
-- Name: team_members team_members_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.team_members
    ADD CONSTRAINT team_members_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: teams teams_rr_cursor_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.teams
    ADD CONSTRAINT teams_rr_cursor_user_id_fkey FOREIGN KEY (rr_cursor_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: thread_links thread_links_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_links
    ADD CONSTRAINT thread_links_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: thread_links thread_links_from_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_links
    ADD CONSTRAINT thread_links_from_thread_id_fkey FOREIGN KEY (from_thread_id) REFERENCES public.threads(id) ON DELETE CASCADE;


--
-- Name: thread_links thread_links_to_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_links
    ADD CONSTRAINT thread_links_to_thread_id_fkey FOREIGN KEY (to_thread_id) REFERENCES public.threads(id) ON DELETE CASCADE;


--
-- Name: thread_parts thread_parts_author_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_parts
    ADD CONSTRAINT thread_parts_author_contact_id_fkey FOREIGN KEY (author_contact_id) REFERENCES public.contacts(id) ON DELETE SET NULL;


--
-- Name: thread_parts thread_parts_author_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_parts
    ADD CONSTRAINT thread_parts_author_user_id_fkey FOREIGN KEY (author_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: thread_parts thread_parts_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_parts
    ADD CONSTRAINT thread_parts_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.threads(id) ON DELETE CASCADE;


--
-- Name: thread_reads thread_reads_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_reads
    ADD CONSTRAINT thread_reads_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.threads(id) ON DELETE CASCADE;


--
-- Name: thread_reads thread_reads_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_reads
    ADD CONSTRAINT thread_reads_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--
-- Name: thread_tags thread_tags_tag_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_tags
    ADD CONSTRAINT thread_tags_tag_id_fkey FOREIGN KEY (tag_id) REFERENCES public.tags(id) ON DELETE CASCADE;


--
-- Name: thread_tags thread_tags_thread_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.thread_tags
    ADD CONSTRAINT thread_tags_thread_id_fkey FOREIGN KEY (thread_id) REFERENCES public.threads(id) ON DELETE CASCADE;


--
-- Name: threads threads_assignee_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads
    ADD CONSTRAINT threads_assignee_team_id_fkey FOREIGN KEY (assignee_team_id) REFERENCES public.teams(id) ON DELETE SET NULL;


--
-- Name: threads threads_assignee_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads
    ADD CONSTRAINT threads_assignee_user_id_fkey FOREIGN KEY (assignee_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: threads threads_contact_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads
    ADD CONSTRAINT threads_contact_id_fkey FOREIGN KEY (contact_id) REFERENCES public.contacts(id) ON DELETE SET NULL;


--
-- Name: threads threads_ticket_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads
    ADD CONSTRAINT threads_ticket_state_id_fkey FOREIGN KEY (ticket_state_id) REFERENCES public.ticket_states(id) ON DELETE RESTRICT;


--
-- Name: threads threads_ticket_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.threads
    ADD CONSTRAINT threads_ticket_type_id_fkey FOREIGN KEY (ticket_type_id) REFERENCES public.ticket_types(id) ON DELETE RESTRICT;


--
-- Name: ticket_type_attributes ticket_type_attributes_ticket_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_type_attributes
    ADD CONSTRAINT ticket_type_attributes_ticket_type_id_fkey FOREIGN KEY (ticket_type_id) REFERENCES public.ticket_types(id) ON DELETE CASCADE;


--
-- Name: ticket_type_states ticket_type_states_state_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_type_states
    ADD CONSTRAINT ticket_type_states_state_id_fkey FOREIGN KEY (state_id) REFERENCES public.ticket_states(id) ON DELETE RESTRICT;


--
-- Name: ticket_type_states ticket_type_states_ticket_type_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_type_states
    ADD CONSTRAINT ticket_type_states_ticket_type_id_fkey FOREIGN KEY (ticket_type_id) REFERENCES public.ticket_types(id) ON DELETE CASCADE;


--
-- Name: ticket_types ticket_types_default_team_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ticket_types
    ADD CONSTRAINT ticket_types_default_team_id_fkey FOREIGN KEY (default_team_id) REFERENCES public.teams(id) ON DELETE SET NULL;


--
-- Name: view_events view_events_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.view_events
    ADD CONSTRAINT view_events_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: view_events view_events_search_event_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.view_events
    ADD CONSTRAINT view_events_search_event_id_fkey FOREIGN KEY (search_event_id) REFERENCES public.search_events(id) ON DELETE SET NULL;


--
-- Name: view_events view_events_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.view_events
    ADD CONSTRAINT view_events_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: view_events view_events_version_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.view_events
    ADD CONSTRAINT view_events_version_id_fkey FOREIGN KEY (version_id) REFERENCES public.article_versions(id) ON DELETE SET NULL;


--
-- Name: votes votes_article_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_article_id_fkey FOREIGN KEY (article_id) REFERENCES public.articles(id) ON DELETE CASCADE;


--
-- Name: votes votes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.votes
    ADD CONSTRAINT votes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: webhook_deliveries webhook_deliveries_activity_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_deliveries
    ADD CONSTRAINT webhook_deliveries_activity_id_fkey FOREIGN KEY (activity_id) REFERENCES public.activities(id) ON DELETE CASCADE;


--
-- Name: webhook_deliveries webhook_deliveries_webhook_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhook_deliveries
    ADD CONSTRAINT webhook_deliveries_webhook_id_fkey FOREIGN KEY (webhook_id) REFERENCES public.webhooks(id) ON DELETE CASCADE;


--
-- Name: webhooks webhooks_created_by_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.webhooks
    ADD CONSTRAINT webhooks_created_by_id_fkey FOREIGN KEY (created_by_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: audit_events; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.audit_events ENABLE ROW LEVEL SECURITY;

--
-- Name: audit_events audit_insert; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_insert ON public.audit_events FOR INSERT WITH CHECK (true);


--
-- Name: audit_events audit_read; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY audit_read ON public.audit_events FOR SELECT USING ((public.app_flag('compliance'::text) OR (public.app_actor_type() = 'system'::text)));


--
-- Name: contacts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.contacts ENABLE ROW LEVEL SECURITY;

--
-- Name: contacts contacts_agent; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contacts_agent ON public.contacts USING (((public.app_actor_type() = 'user'::text) AND (public.app_flag('see_all_contacts'::text) OR (EXISTS ( SELECT 1
   FROM public.threads t
  WHERE (t.contact_id = contacts.id))))));


--
-- Name: contacts contacts_self; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contacts_self ON public.contacts USING (((public.app_actor_type() = 'contact'::text) AND (id = public.app_contact_id())));


--
-- Name: contacts contacts_system; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY contacts_system ON public.contacts USING ((public.app_actor_type() = 'system'::text));


--
-- Name: thread_parts; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.thread_parts ENABLE ROW LEVEL SECURITY;

--
-- Name: thread_parts thread_parts_agent; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY thread_parts_agent ON public.thread_parts USING (((public.app_actor_type() = 'user'::text) AND (EXISTS ( SELECT 1
   FROM public.threads t
  WHERE (t.id = thread_parts.thread_id)))));


--
-- Name: thread_parts thread_parts_contact; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY thread_parts_contact ON public.thread_parts USING (((public.app_actor_type() = 'contact'::text) AND (kind = ANY (ARRAY['comment'::text, 'rating'::text, 'article'::text, 'close'::text, 'open'::text, 'ticket_state_change'::text])) AND (EXISTS ( SELECT 1
   FROM public.threads t
  WHERE (t.id = thread_parts.thread_id)))));


--
-- Name: thread_parts thread_parts_system; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY thread_parts_system ON public.thread_parts USING ((public.app_actor_type() = 'system'::text));


--
-- Name: threads; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.threads ENABLE ROW LEVEL SECURITY;

--
-- Name: threads threads_agent; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY threads_agent ON public.threads USING (((public.app_actor_type() = 'user'::text) AND (public.app_flag('see_all'::text) OR (assignee_user_id = public.app_user_id()) OR (assignee_team_id IN ( SELECT team_members.team_id
   FROM public.team_members
  WHERE (team_members.user_id = public.app_user_id()))) OR ((assignee_user_id IS NULL) AND (assignee_team_id IS NULL)))));


--
-- Name: threads threads_contact; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY threads_contact ON public.threads USING (((public.app_actor_type() = 'contact'::text) AND (contact_id = public.app_contact_id()) AND ((kind = 'conversation'::text) OR is_shared)));


--
-- Name: threads threads_system; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY threads_system ON public.threads USING ((public.app_actor_type() = 'system'::text));


--
-- PostgreSQL database dump complete
--

SET search_path TO "$user", public;

INSERT INTO "schema_migrations" (version) VALUES
('20261104120000'),
('20261104090100'),
('20261104090001'),
('20261104090000'),
('20261103203600'),
('20261103203550'),
('20261103203514'),
('20261103203513'),
('20261103203427'),
('20261103203426');

