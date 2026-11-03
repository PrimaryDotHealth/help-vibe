# Architecture: helpvibe

A rebuild of Helpjuice's knowledge base (Part 1) and Intercom's support desk
(Part 2), as one Rails 8 app on one Postgres database.

**Decisions (2026-11-03):**
- **Rails 8.1 (Ruby 4.0) + Postgres 17**, replacing Rust + SQLite. Reasons:
  - Rails 8 ships the pieces we'd otherwise hand-build: inbound email, realtime, jobs, rich text, generated migrations.
  - AI tooling is very fluent in it.
  - It still fits one small server: about $15/month on AWS under a BAA.
- **No CDN, no Node.** JavaScript is served from the app via Importmap (pins vendored into `vendor/javascript`). CSS is plain files via Propshaft. Fonts are local woff2.
- **One database.** Postgres holds the app data, the job queue (Solid Queue), the realtime fan-out (Solid Cable) and the cache (Solid Cache). No Redis.

```
bin/rails server                      # web + jobs in one process (SOLID_QUEUE_IN_PUMA=1)
bin/rails db:prepare                  # create + migrate
bin/rails helpvibe:user[you@company.com,superadmin]
bin/rails helpvibe:import:helpjuice   # reads HELPJUICE_SUBDOMAIN / HELPJUICE_API_KEY from env
kamal deploy                          # one EC2 box: app container + Postgres accessory
```

## Stack

| layer | choice | why |
| --- | --- | --- |
| language / framework | Ruby 4.0, **Rails 8.1** | conventions keep our code small. Generators for models, migrations, mailers, jobs. |
| database | **PostgreSQL 17** | one database for everything. Partial unique indexes, check constraints, generated tsvector columns, pg_trgm, row-level security, triggers. |
| schema format | `config.active_record.schema_format = :sql` (`db/structure.sql`) | RLS policies, functions, triggers and generated columns don't round-trip through `schema.rb`. |
| HTML | ERB views, server-rendered, **Hotwire** (Turbo + Stimulus) | pages work without JS. Turbo Frames/Streams give partial updates without a SPA. |
| JS delivery | **importmap-rails**, pins downloaded into `vendor/javascript/` | no Node, no bundler, no CDN at runtime. |
| CSS | **Propshaft** + one hand-written stylesheet from the design tokens (`app/assets/stylesheets/`) | the "clinic handbook" design in `replica/screens/styles.css` becomes the real stylesheet. No Tailwind build. |
| rich text editor | **Action Text** as the storage/rendering layer. The editor is decided in an M0 spike: Trix (built in, basic) + custom attachments for callouts/accordions/tabs, vs **Lexxy** (Basecamp's newer Action Text editor), vs a vendored ProseMirror build via importmap | the editor is still our riskiest piece. Action Text gives storage, attachments and sanitising for free whichever editor wins. |
| HTML safety | Action Text's sanitizer + `rails-html-sanitizer` allow-list for imported/pasted HTML | stored HTML is safe to render anywhere, including inside the widget. |
| markdown mode | `commonmarker` gem (md → HTML) | the "Markdown and WYSIWYG" feature. |
| search | Postgres full-text (`tsvector`, weighted title/keywords > subtitle > body, `ts_headline` for highlighting) + **pg_trgm** typo fallback + exact code lookup ("SCH·07") | tested on the schema: stemming, highlighting and "apointment" → SCH·07 all work. No Elasticsearch. |
| auth (staff) | Rails 8 **authentication generator** (has_secure_password, DB sessions) + **rotp** (TOTP 2FA) + **omniauth_openid_connect** (SSO later) | built in. 2FA is required for agents (PHI). |
| authorization | **Action Policy** (or Pundit), one policy per resource **+ Postgres RLS** as a backstop on PHI tables | policies give good errors. RLS means a forgotten scope still can't leak another team's or patient's thread (tested). |
| widget identity | our app's backend signs a short-lived JWT (`jwt` gem, HS256/EdDSA) → `POST /widget/session` → contact session in a **partitioned cookie** (`SameSite=None; Secure; Partitioned`), with a bearer-token fallback | third-party cookies are blocked in iframes, and partitioned cookies are the supported way. |
| realtime | **Turbo Streams over Action Cable**, backed by **Solid Cable** (Postgres) | new messages, assignment, counts, typing and presence, with no Redis. Works across several app processes if we ever add them. |
| background jobs | **Solid Queue** (Postgres), run inside Puma. Schedules in `config/recurring.yml`. | auto-publish/expire, webhooks, email, SLA ticks, retention. One process. |
| email out | **Action Mailer** over SMTP: Amazon SES (BAA-covered). Google Workspace SMTP relay is the alternative. | |
| email in | **Action Mailbox**. Ingress: Amazon SES via `action_mailbox_amazon_ingress` (SNS → our endpoint, signature verified), or a small IMAP poller job (Google Workspace mailbox) feeding `ActionMailbox::InboundEmail`. | routing, storage, bounce/loop handling hooks and threading come built in. The riskiest Part 2 piece becomes mostly configuration. |
| files | **Active Storage**, **Disk service** on the encrypted volume in production (S3 optional) | cheapest "in a box". Files are included in the same backup. Private support attachments are only served via an authorised, audited proxy controller. |
| field encryption | **Active Record Encryption** for TOTP secrets, webhook secrets and API key material | built in. Message bodies stay searchable; they're protected by volume encryption + RLS. |
| content audit / history | our own `activities` (Helpjuice-shaped, drives webhooks) + `audit_events` (PHI access, append-only) | both tables already designed and tested. |
| HTTP clients | **Faraday** (webhooks out, Helpjuice importer) | |
| rate limiting | Rails 8 built-in `rate_limit` in controllers (Solid Cache store) | login, API keys, search, widget messages. |
| observability | Rails logs (with a filter for bodies/emails/names), `/up` health check, optional Sentry (BAA needed if enabled) | |
| deploy | **Kamal 2** to one AWS **t4g.small** (2 GB). Postgres runs as a Kamal accessory on the same box. Encrypted EBS. Thruster in front of Puma. kamal-proxy terminates TLS (Let's Encrypt). | about $15/month. AWS signs a BAA at no extra cost. |
| memory budget | Puma: 1 worker, 3 threads, YJIT + jemalloc, Solid Queue in-process. Postgres `shared_buffers=256MB`. | ~300–400 MB app + ~150–250 MB Postgres, inside 2 GB with room to spare. |
| backups | nightly `pg_dump` + Active Storage files → encrypted with **age** → S3 (BAA-covered, SSE-KMS). Optional WAL archiving for point-in-time recovery. | backups contain PHI, so they're encrypted before leaving the box. |

No microservices, no Node, no Redis, no separate search engine. The only
outside services are SES (email) and S3 (backups), both under the AWS BAA.

### Code layout

```
app/
  models/                 Article, ArticleVersion, Revision, Category, Keyword…,
                          Contact, Company, Thread (conversations + tickets), ThreadPart, Team,
                          TicketType, TicketState, Macro, SlaRule, SlaTimer, Rule, AuditEvent…
  models/concerns/        Codeable (SCH·07), Searchable, Versioned, Audited (PHI reads), RlsScoped
  policies/               Action Policy rules, one per resource (the authz of record)
  controllers/
    reader/               help center: home, chapters, articles, search, votes
    widget/               embed.js, panel, suggestions, conversations, session
    admin/                articles, editor, revisions, reviews, chapters, analytics, settings…
    admin/inbox/          views, threads, parts, assignment, macros, tickets
    api/v3/               Helpjuice-shaped API (+ support resources)
  mailboxes/              SupportMailbox (threads replies, creates conversations)
  mailers/                ReviewMailer, PasswordsMailer, ThreadMailer (link-only by default)
  jobs/                   PublishDueJob, ExpireDueJob, DeliverWebhooksJob, SlaTickJob, UnsnoozeJob,
                          AssignQueueJob, RetentionPurgeJob, RollupCountersJob, ImapPollJob…
  javascript/controllers/ Stimulus: editor glue, widget loader, autosave, presence, slash menu
  views/                  reader/, widget/, admin/ (markup from replica/screens/*)
lib/helpvibe/             sla_clock.rb (office hours + holidays), assigner.rb, search.rb,
                          importers/helpjuice.rb, rls.rb (sets app.* settings per request)
db/migrate/               knowledge base, then support + PHI hardening
config/recurring.yml      job schedules
```

## Schema

The tested Postgres schema is `replica/schema.sql` (0001, 33 tables) and
`replica/schema-0002-support.sql` (0002, 29 tables). 62 tables in all, loaded
into Postgres 17.11 and tested on 2026-11-03. Both become Rails migrations
(`create_table` with `check_constraint`, partial `add_index … where:`,
`t.virtual … stored: true` for tsvector columns, and `execute` for RLS
policies, functions and triggers).

Adjustments when converting to Rails:

- **Files move to Active Storage.** Our `uploads` and `part_attachments` tables are replaced by Active Storage's three tables. The 25 MiB limit, the sha256 dedupe and the `private` flag move to model validations and blob metadata. Private support files are never given public URLs: they're served through `Admin::AttachmentsController` / `Widget::AttachmentsController`, which authorise, audit and stream.
- **Rich text moves to Action Text** for revisions (`has_rich_text :body`). `body_text` stays a real column for search, diffs and email.
- **Users and sessions** come from the Rails 8 authentication generator, extended with our columns: role, lockout, availability, TOTP, permissions.
- Everything else maps one-to-one, including every check constraint, partial unique index, the audit trigger and the RLS policies.

Hard constraints the database enforces (all tested in Postgres):

- One live version per article per language. Only a published version can be the default.
- One open review per version. A category with children or articles can't be deleted.
- Article codes must look like `SCH·07`. Only top-level chapters carry a code.
- A webhook event is never queued twice. One vote per visitor per article.
- A ticket always has a type, a state, attributes and a shared flag. A conversation has none of these.
- Customers can't author notes or events.
- Sending twice from the composer or widget can't create two messages (`client_id`).
- One active SLA timer per thread per kind.
- **Audit events can't be updated, or deleted before they're 6 years old, even by the table owner** (trigger). The app role has no UPDATE/DELETE grant on them at all.
- **RLS**: with no actor set, PHI tables return nothing. A billing agent sees billing and unassigned threads but not tech's. A patient sees only their own threads and never internal notes. Contacts see only themselves. Audit rows need the compliance flag.

### RLS from Rails

`Helpvibe::Rls` runs in an `around_action` (and in jobs) on the request's
checked-out connection:

```ruby
conn.exec_query("select set_config('app.actor_type', $1, false), set_config('app.user_id', $2, false), …", …)
yield
ensure
conn.exec_query("select set_config('app.actor_type', '', false), …")   # never leak to the next request
```

Session-level settings are always reset in `ensure`, because Puma threads
reuse connections. Jobs run as `system`. Migrations run as the owner role.
In production the app connects as `helpvibe_app`, which does not own the
tables (otherwise RLS is bypassed). In development and tests a second role
is used the same way, so RLS is exercised everywhere.

## Routes

Same paths as the previous plan, as Rails resources. Auth legend: **anon**,
**reader** (JWT/contact or signed-in viewer+), **draft** (draft_writer+),
**collab**, **admin**, **super**, **agent** (in a team), **contact**, **key**
(API key).

### Reader (help center), Part 1

| route | does | who |
| --- | --- | --- |
| `GET /` | contents page (S01) | anon |
| `GET /c/:slug` | chapter (S02) | anon |
| `GET /a/:slug`, `/a/:slug/v/:n` | article, specific version (S03) | anon (visibility rules) |
| `GET /search`, `/search/suggest` | results, typeahead (S04) | anon |
| `POST /a/:slug/vote`, `POST /e/view` | feedback, view ping | anon |
| `GET /files/:signed_id` | public help-center media | anon if a visible article uses it |
| `GET|POST /session`, `/passwords` | staff sign-in, reset (generator) | anon |
| fallback | `slug_redirects` lookup → 301 (old slugs, old codes, Helpjuice paths) | anon |

### Widget, Parts 1 + 2

| route | does | who |
| --- | --- | --- |
| `GET /embed.js` | loader: launcher, iframe panel, `HelpVibe.open/identify/setPage` | anon |
| `POST /widget/session` | our app's JWT → contact session | our backend's token |
| `GET /widget`, `/widget/suggest`, `/widget/search`, `/widget/a/:slug` | panel, page suggestions, search, article (S07) | anon / contact |
| `GET /widget/home` | ask button, my conversations (S24) | contact |
| `resources /widget/threads` (+ `parts`, `rating`, `typing`) | start, list, read, reply, rate (S25–S27) | contact (anon with email = unverified) |
| `GET /t/:token` | magic link for email-only contacts | link holder, 24 h |
| `GET /embed/a/:slug` | chromeless article for iframes (S08) | anon / contact |

Realtime: Turbo Stream subscriptions on signed stream names (`thread_<id>`,
`contact_<id>`, `user_<id>`, `team_<id>`). Action Cable connections
authenticate with the staff session or the contact session.

### Admin (knowledge base), Part 1

| route | does | who |
| --- | --- | --- |
| `GET /admin` | overview | draft |
| `resources :articles` (+ `settings`, `versions`, `archive`) | list (S11), create, settings, new version | draft / collab |
| `POST /admin/versions/:id/revisions` | save / autosave (409 on stale `base_revision_id`) | draft |
| `POST /admin/versions/:id/publish`, `/unpublish` | publish now / schedule | collab (or review bypass) |
| `GET /admin/versions/:id/revisions`, `/admin/revisions/:a/diff/:b`, `POST …/restore` | history, diff, restore (S13) | draft |
| `resources :reviews` (+ `decide`, `cancel`), `resources :comments` | review (S14), inline comments | draft / reviewer |
| `resources :chapters` (+ `move`) | tree (S15) | collab |
| `resources :users`, `:groups` | people | admin |
| `resources :context_rules` | page suggestions | collab |
| `GET /admin/analytics…` | S19 | admin |
| `resources :api_keys`, `:webhooks` (+ `toggle`, `test`, `deliveries`) | developers (S20) | admin |
| `/admin/settings`, `/admin/customize`, `/admin/backup`, `/admin/import/helpjuice` | S18, S21, S22 | admin / super |

### Admin (support desk), Part 2

| route | does | who |
| --- | --- | --- |
| `GET /admin/inbox(/:view)` | mine, mentions, unassigned, team/:id, all, saved/:id, sla-at-risk (S29) | agent |
| `resources :threads, param: :number` (+ `parts`, `assign`, `state`, `priority`, `tags`, `typing`, `viewing`) | thread + sidebar (S30, S31), audited view | agent (policy + RLS) |
| `POST /admin/threads/:n/ticket`, `PUT …/ticket`, `POST …/handoff` | convert, update state/fields, back-office hand-off (S32, F14) | agent |
| `POST /admin/trackers/:n/link`, `…/notify` | tracker (S33, F15) | agent |
| `POST /admin/threads/:n/draft_article` | F18 → editor | draft+ |
| `resources :contacts` (+ `merge`, `export`) | S34 | agent / admin |
| `resources :macros` | S35 | agent / admin |
| `/admin/settings/{tickets,teams,sla,office_hours,rules,email}` | S36–S39, S41 | admin |
| `GET /admin/reports/support` | S40 | admin |
| `GET /admin/audit`, `POST /admin/audit/export` | S42 | compliance |
| `/admin/security/two_factor`, `/auth/:provider/callback` | 2FA, SSO | user |

### API `/api/v3` (Helpjuice-shaped, plus support resources)

`search`, `articles` (+ `upvote`/`downvote`), `categories`, `users`, `groups`,
`activities`, `webhooks`, `analytics/*`. Part 2 adds `conversations`,
`tickets`, `contacts`, `ticket_types` and `tags`. Envelope
`{meta: {current, limit, total_pages, total_count}, …}`, limit 25 (max 1000),
100 req/min per key (`rate_limit`). Reads of PHI over the API are audited.

### Webhooks

- **In:** `POST /rails/action_mailbox/amazon/inbound_emails` (SES via SNS, signature verified by the ingress gem).
- **Out:** Helpjuice's 14 event names, plus `conversation_create`, `conversation_reply`, `conversation_assign`, `conversation_close`, `ticket_create`, `ticket_state_change` and `contact_create`.
  - Headers: `X-Helpvibe-Signature: t=…,v1=HMAC-SHA256`, plus `X-Helpvibe-Delivery` for dedupe.
  - Retries at 1m, 5m, 30m, 2h and 12h, then marked dead.

### Jobs (`config/recurring.yml`, Solid Queue)

| job | schedule | what |
| --- | --- | --- |
| PublishDueJob / ExpireDueJob | every 30 s | scheduled publish and expiry |
| DeliverWebhooksJob | every 5 s (plus enqueued on activity) | due deliveries, at most 4 in flight |
| UnsnoozeJob | every 30 s | snoozed → open, notify assignee |
| SlaTickJob | every 30 s | missed / at-risk timers → notify |
| AssignQueueJob | every 15 s, and when an agent goes active | round robin / balanced, `FOR UPDATE` on the team row |
| ImapPollJob | every 30 s (IMAP ingress only) | fetch new mail → Action Mailbox |
| NotifyDigestJob | every 5 min | email unread notifications to offline agents |
| RetentionPurgeJob | nightly 02:00 UTC | delete threads past `purge_after` (audit event first) |
| RollupCountersJob / SearchReconcileJob | nightly | article counters, stale search rows |
| BackupJob | nightly 03:00 UTC | pg_dump + storage → age → S3. Keep per retention policy. |
| CleanupJob | hourly | expired sessions/tokens, old autosaves, inbound email > 30 days (Action Mailbox incineration) |

## The parts that bite

- **The editor.** Still the biggest risk.
  - M0 spike: Trix + custom attachments vs Lexxy vs vendored ProseMirror.
  - Prove the custom blocks: note/caution callouts, questions (accordion), tabs, tables, code, images, links to articles by code.
  - Prove paste from Google Docs and markdown round-trips.
- **RLS + connection reuse.** Settings are session-level on pooled connections, so they must be reset in `ensure`. There's a test that runs two requests on one thread with different actors.
- **Time zones.** Store UTC, render in the viewer's zone. Scheduled publish is entered in the editor's zone. SLA math uses the team's IANA zone (`ActiveSupport::TimeZone` / tzinfo), so DST and holidays are correct.
- **Idempotency.**
  - Composer and widget sends carry a `client_id`, unique per thread.
  - Webhook deliveries are unique per (webhook, activity).
  - Action Mailbox dedupes inbound mail by Message-ID.
  - The Helpjuice importer is idempotent through `import_map`.
- **Races.**
  - Article saves on a stale base revision return 409, with "Lee saved a newer copy".
  - Publish is one transaction guarded by the one-default index.
  - Assignment locks the team row (`FOR UPDATE`) so two threads can't take the last free slot.
- **Realtime.**
  - Turbo Stream broadcasts happen `after_commit`, so a rolled-back write never shows up.
  - Clients that reconnect re-fetch the thread frame, so missed broadcasts don't matter.
  - Typing and presence are throttled (one per 3 s) and expire after 10 s.
- **Email threading and loops.**
  - Matched by `In-Reply-To`/`References`, then a reply token address (`support+t<token>@`), then sender + subject within 7 days.
  - `Auto-Submitted`, `X-Autoreply` and `Precedence: bulk` are ignored, and no auto-reply goes to the same sender more than once an hour.
  - Notification emails default to **link only** (no PHI in the email body).
- **Identity spoofing.**
  - Contacts are trusted only from our app's signed JWT.
  - Email-only contacts are unverified and only see a thread through its magic link.
  - An email from a known address never logs anyone in.
- **XSS.** All article and message HTML goes through the sanitizer. Templates have no inline scripts, so a strict CSP applies. Custom CSS is admin-only.
- **File uploads.** 25 MiB limit, content type sniffed (Marcel), images re-encoded to strip EXIF (`image_processing` + libvips in the container). SVG is downloaded, never rendered inline. Private files are never given public URLs.
- **PHI in logs.** `filter_parameters` covers bodies, emails, names and tokens. Log lines carry ids only. Sentry is off unless BAA-covered.
- **Search privacy.** Raw queries from identified contacts aren't stored (`support.store_identified_searches=false`). Filtering by visibility happens in SQL, never after the fact.
- **Memory on a 2 GB box.** Run 1 Puma worker with 3 threads, YJIT and jemalloc, and Solid Queue inside Puma. Watch RSS. If it creeps past 600 MB, set Puma's worker killer limit or move to a 4 GB box (about $24/month).
- **Backups** contain PHI, so they're age-encrypted with the key held outside the bucket. Restores are tested quarterly.
- **GDPR / HIPAA deletion.** Per-contact export and delete, a retention purge, and author nullification (`on delete set null`) for staff who leave.

## Build order

**M0. Spikes (2–3 days).**
- The editor choice, with the block round-trips listed above.
- Postgres search ranking on a sample of our real articles.
- `embed.js` + the partitioned cookie inside our real app with its CSP.

**M1. Vertical slice (Part 1 core loop).**
- Screens: S09, S11, S12 (basic editor, autosave), S01, S03, S04, S07 (launcher, search, article view).
- Models: User, Session, Category, Article, ArticleVersion, Revision, SearchIndex, SearchEvent, ViewEvent.
- Done when: create a superadmin with the rake task, write and publish an article, then find it from the widget inside our app.

**M2. Part 1 must-haves.** Five roles, invites, groups. Nested chapters with
codes, also-in categories, redirects. Uploads (Active Storage). Draft on top
of published, history, restore. Visibility + accessors + the widget JWT. TOC,
keyword-boosted search. Iframe embed. `/api/v3` reads + API keys. The
Helpjuice importer. Kamal deploy to the t4g.small.

**M3. Part 1 should-haves.**
- Editor: markdown mode, all blocks, diff, multiple published versions, scheduled publish.
- Review and comments, email notifications.
- Readers: votes, related articles, reader sign-in.
- Widget: page suggestions.
- Admin: analytics, activity log, API writes, webhooks, backups.

**M4. Part 1 could-haves** (customization, link-only, files manager, planner,
IP allow-list, auto-join…).

**M5. Compliance base + support vertical slice.**
- Compliance base:
  - Encrypted EBS, age backups, log filtering.
  - 2FA for agents, 15-minute idle sign-out.
  - `audit_events` + the Audited concern, RLS + `Helpvibe::Rls` with its tests.
- The slice:
  - Screens: S24, S25, S26, S29 (mine + unassigned), S30 (reply, note, close), S42 (read-only).
  - Done when a signed-in patient asks in the widget, an agent sees it live and replies, and the patient sees the reply live. Every view of it is in the access log.

**M6. Support must-haves.**
- Inbox and routing: teams, assign, mentions, collision warning, insert article by code, contact sidebar.
- Email via Action Mailbox + SES, link-only notifications, magic links.
- Macros and private attachments.
- SSO for agents.
- Retention and per-contact export/delete.

**M7. Support should-haves.**
- Tickets: types with custom fields and states, back-office hand-off.
- Routing and inbox: tags, priority, saved views, round robin/balanced, rules.
- SLAs and office hours.
- Customer and reporting: CSAT, reports, draft-an-article (F18).
- API: support API and webhooks.

**M8. Support could-haves.** Trackers with notify-all, companies, the
"tickets after reading an article" report.

**M9. replica-entrepreneur fixes.** Skipped by default (internal tool).

## Decisions still open

1. **Inbound email ingress:** Amazon SES via Action Mailbox (recommended, since we're on AWS anyway) or an IMAP poller on a Google Workspace mailbox.
2. **The AWS account for the BAA,** and whether to start Part 1 on a cheaper non-BAA host before any PHI exists.
3. **Anonymous visitors:** allow them to write in with just an email (as unverified contacts), or require sign-in through our app.
4. ~~The editor~~ **Decided in M0 (2026-11-03): Lexxy 1.0.3**, Basecamp's Lexical-based editor for Action Text.
   - It replaces Action Text's default editor, and its JavaScript ships inside the gem (no CDN, no Node).
   - It has tables, code blocks, headings, lists and markdown shortcuts built in.
   - Callouts, Q&A and tabs are still to build (M3) as Action Text attachments.
   - Stored content is Action Text's canonical HTML, so switching editors later doesn't need a data migration.
