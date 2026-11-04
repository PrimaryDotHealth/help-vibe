# Recon map: Helpjuice (web)

Scope: **Part 1 (Helpjuice):** the knowledge-base CMS: write, review, version
and publish help articles, organize them in categories with access control,
search them, and embed them in our own app. Admin side, public reader side,
embed widget, REST API and webhooks.
**Part 2 (Intercom, added 2026-11-03):** the support desk: conversations
started from the same widget, a shared team inbox, tickets with types and
states, email, assignment, saved replies, SLAs and reports. Intercom's AI,
outbound marketing and extra channels are out. See "Part 2" below.
For: Internal use at our company (helpvibe). It replaces our Helpjuice
subscription and won't be sold. Built as "Helpjuice in a box": one Rust binary
and one database, with no CDN or external frontend dependencies.
Date: 2026-11-03

## Assumptions (unconfirmed by the user, defaults used)

| # | assumption | change it if... |
| --- | --- | --- |
| A1 | We embed help in our app with a JS widget or iframe, and possibly API calls. Exact current integration unknown. | you send the snippet from our app |
| A2 | Single language (en_US) at launch, with the data model ready for more | you publish in several languages |
| A3 | Editors sign in with email + password. SSO (OIDC) comes later. | you need Okta/Google SSO day one |
| A4 | ~~Articles contain no PHI, so the system is out of HIPAA scope~~ **Revised for Part 2:** support conversations will contain PHI, so the whole system is treated as in HIPAA scope (see "Compliance" in Part 2) | n/a |
| A9 | Both patients and clinic staff can write in, identified by the same signed token as the widget | only one audience writes in |
| A10 | No existing helpdesk history to import (fresh start) | we're moving off Intercom/Zendesk |
| A11 | A support team of 5–20 people in 1–3 teams (e.g. general, billing, technical) | much bigger or smaller |
| A12 | Email in and out is needed for the first support release | in-app only is fine to start |
| A5 | No AI chatbot. Search is keyword/full-text. | you want AI answers |
| A6 | A few hundred articles migrated from Helpjuice via its API v3, using our own key | volume or attachments are very large |
| A7 | One knowledge base (single tenant) | you need several KBs |
| A8 | ~~SQLite~~ **Postgres 17** as the single database (decided 2026-11-03), with full-text search + pg_trgm. Rails 8.1 app (see architecture.md) | n/a |

Terms: Helpjuice's terms weren't reviewed. Building an internal replacement
for our own use isn't building a competitor, but check our agreement. This
recon used **public docs only**: no account, no app source, no network
inspection.

## Sources

| # | source | URL | notes |
| --- | --- | --- | --- |
| 1 | help center home | https://help.helpjuice.com/ | 9 top-level categories, feature inventory |
| 2 | API v3 reference | https://help.helpjuice.com/en_US/api-v3/using-api-v3 | full resource/field list, the best data-model evidence |
| 3 | webhooks | https://help.helpjuice.com/en_US/api-v3/overview-webhooks | 14 events, payload shape, no signing documented |
| 4 | analytics API | https://help.helpjuice.com/en_US/api-v3/analytics-api | metrics: searches, dead ends, views, readings, likes, time spent |
| 5 | JS embed install | https://help.helpjuice.com/how-to-install-helpjuice | embed div, account URL, hash routing, cookie problem with internal content |
| 6 | Swifty helpbar | https://help.helpjuice.com/en_US/swifty-ai/swifty-ai-helpbar | in-app search widget, ranking factors, public-only when embedded |
| 7 | article editor category | https://help.helpjuice.com/en_US/article-editor | 28 article titles = editor feature list |
| 8 | versions & revisions | https://help.helpjuice.com/what-are-article-versions-and-revisions | Article > Version > Revision, compare, restore |
| 9 | review process | https://help.helpjuice.com/article-editor/review-process | reviewers, approve/disapprove, any/all rule, bypass roles |
| 10 | user roles | https://help.helpjuice.com/getting-started/how-to-set-up-user-roles | 5 roles and their permissions |
| 11 | settings category | https://help.helpjuice.com/en_US/settings | allowed IPs, JS-only access, contact form, custom domain |
| 12 | authentication category | https://help.helpjuice.com/en_US/authentication | SSO: Okta, JWT, ADFS, Azure AD, LDAP, Google |
| 13 | pricing (third party) | https://ferndesk.com/blog/helpjuice-pricing, https://www.capterra.com/p/130533/Helpjuice/pricing/ | priced per author, unlimited readers. AI on higher tiers. |
| 14 | our own Helpjuice account | (not used) | screenshots wanted in `replica/screens/` |

## Core loop

An author writes an article, gets it approved and publishes it. A user inside
our app opens contextual help, searches or browses, and reads the answer
without leaving the app.

## Screens

Reader side (public KB, served by helpvibe):

| ID | screen | route / how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S01 | KB home | `/` | entry point | search box, category grid, popular articles | filled, empty KB |
| S02 | category page | `/c/:slug` | browse one category | breadcrumb, subcategory list, article list | filled, empty, no permission |
| S03 | article page | `/a/:slug` | read an article | title, subtitle, body, TOC, related articles, helpful yes/no, updated date, version switcher | filled, not found, no permission, older version |
| S04 | search results | `/search?q=` | find answers | search box, results with snippets + highlight, category filter | results, no results (dead end), typo-tolerant |
| S05 | contact form | `/contact` | escalate when no answer | form, captcha (optional), success | filled, error, sent |
| S06 | reader sign-in | `/login` | internal content for staff | email/password, SSO button | error, locked out |

Embed (inside our app):

| ID | screen | route / how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S07 | help widget | `<script src="https://help.example/embed.js">` | in-app help panel | launcher button, panel, search, suggested articles for this page, article view, back, contact link | closed, open, searching, no results, article, offline/error |
| S08 | inline article embed | iframe `/embed/a/:slug` or `#hash` route | one article inside a page of our app | chromeless article | filled, not found |

Admin side:

| ID | screen | route / how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S09 | admin sign-in / reset | `/admin/login` | editors sign in | form, reset link | error, locked out, reset sent |
| S10 | dashboard | `/admin` | what's happening | recent activity, my drafts, awaiting my review, failed searches | empty, filled |
| S11 | article list | `/admin/articles` | find and manage content | table, filters (status, category, author, visibility), bulk move/archive | empty, filled, filtered-empty |
| S12 | article editor | `/admin/articles/:id/edit` | write content | WYSIWYG + markdown toggle, toolbar, blocks (callout, accordion, tabs, table, code, image, video, file, internal section), status manager, settings drawer (slug, categories, keywords, visibility, accessors, auto-publish/expire dates), autosave indicator | new, draft, published, published-with-draft, saving, save failed, conflict |
| S13 | revision history | editor → More → Revision history | compare and restore | revision list, side-by-side/inline diff, "make current" | one revision, many |
| S14 | review panel | editor → Request review | approval | reviewer picker, note, inline comments, approve/disapprove, status tag | requested, approved, changes requested |
| S15 | categories | `/admin/categories` | organize the tree | drag-drop tree, accessibility per category, accessors, archive | empty, deep tree |
| S16 | files manager | `/admin/files` | uploaded media | grid/list, upload, usage, delete | empty, uploading, too large |
| S17 | users & groups | `/admin/users`, `/admin/groups` | access | user table, invite, role select, deactivate, groups with auto-email-domain rule | empty, filled |
| S18 | settings | `/admin/settings` | KB-wide config | name, contact email, review rules, allowed IPs, JS-only access, password expiry, top-articles count | saved, invalid |
| S19 | analytics | `/admin/analytics` | what readers need | searches, dead-end & bounced searches, top articles, views/readings/time spent, helpful ratio, date range | empty, filled |
| S20 | API & webhooks | `/admin/developers` | integrate | API keys, webhook list, event picker, test, last response code | empty, filled, failing |
| S21 | customization | `/admin/customize` | look & feel | logo, colours, header links, custom CSS, widget theme | default, custom |
| S22 | backup & import | `/admin/backup` | safety & migration | download backup, restore, Helpjuice import progress | idle, running, done, error |
| S23 | article planner | `/admin/planner` | kanban of work | columns (idea, draft, review, published) | empty, filled |

## Flows

```
F01 Author writes and publishes a new article
    S11 -> S12 (new) -> write, autosave -> settings drawer (category, visibility) -> Publish -> S03
    happy path clicks: ~5
    edge: autosave fails offline, slug clash, draft writer can't publish, two editors at once

F02 Update a published article without touching the live copy
    S03/S11 -> S12 (edit published → new draft version) -> save -> Publish -> live version replaced
    happy path clicks: ~4
    edge: abandon draft, publish an older version again, scheduled auto-publish, expiry date passes

F03 Review and approve
    S12 -> S14 Request review (pick reviewers, note) -> email -> reviewer S12 inline comments ->
    approve | disapprove(message) -> author edits, resubmits -> approved -> publish
    happy path clicks: ~6
    edge: rule "any" vs "all" approvers, bypass roles, reviewer deactivated, private article with group accessors

F04 User of our app gets help in context   (the core loop, reader side)
    our app page -> S07 launcher -> suggested articles for this page -> article -> helpful yes/no
    or: S07 search -> results -> article -> back -> contact
    happy path clicks: 2 (open, pick suggestion)
    edge: no suggestions for this page, no results (logged as dead end), internal article in embed,
          slow network, host page on SPA route change

F05 Reader searches the public KB
    S01 -> S04 -> S03 -> helpful vote
    happy path clicks: 2
    edge: typo, zero results, query matching keywords only, article in two categories

F06 Organize categories
    S15 -> create / drag to reparent / reorder / set accessibility -> articles follow
    edge: delete non-empty category, move into own descendant, private category with public article

F07 Restore an old revision
    S12 -> S13 -> pick revision -> compare -> Make current
    edge: compare across versions (not supported in original)

F08 Migrate from Helpjuice   (ours, not in the original)
    S22 -> enter Helpjuice subdomain + API key -> import categories, articles, users, groups, uploads -> report
    edge: rate limit 100 req/min, missing images, broken internal links, slug collisions

F09 Developer integrates
    S20 -> create API key -> call /api/v3/articles... | add webhook -> test -> receive event
    edge: key revoked, webhook endpoint down (retries), duplicate delivery

F10 Admin manages access
    S17 -> invite user -> pick role -> add to group -> set article/category accessors
    edge: deactivate last superadmin, group auto-join by email domain
```

## Components

| component | variants | states | used on |
| --- | --- | --- | --- |
| Button | primary, secondary, ghost, danger | default, hover, focus, disabled, loading | all |
| Text input / textarea | default, search, with icon | default, focus, error, disabled | all |
| Select / multi-select | single, multi with chips, user/group picker | open, empty, loading | S11, S12, S14, S17 |
| Search box | page header, hero, widget | typing, results dropdown, empty | S01, S04, S07, S11 |
| Data table | sortable, selectable rows, bulk bar | empty, loading, filtered-empty | S11, S16, S17, S20 |
| Tree | drag-and-drop, collapsible | dragging, drop-invalid | S15, S02 sidebar |
| Rich text editor | WYSIWYG, markdown source | focus, saving, saved, failed | S12 |
| Editor blocks | callout (info/warn/danger/success), accordion, tabs, table, code, image, video, file, internal section, TOC | edit, read | S12, S03 |
| Status badge | draft, published, published+draft, in review, approved, changes requested, archived, scheduled, expired | - | S11, S12, S23 |
| Diff view | inline, side-by-side | no changes | S13 |
| Modal / drawer | confirm, form, settings drawer | open, submitting | S12, S14, S15, S17 |
| Toast | success, error, info | auto-dismiss | all admin |
| Breadcrumb | - | - | S02, S03 |
| Article card / result row | with snippet + highlight | - | S01, S02, S04, S07 |
| Feedback (helpful?) | yes/no, then optional comment | voted | S03, S07 |
| Empty state | per screen | - | all |
| Widget launcher + panel | floating button, side panel | closed, open, loading, error | S07 |
| Tabs | admin sections, editor tabs block | - | S12, S18, S19 |
| Chart | line (over time), bar (top N) | empty | S19 |

## Inferred data model

```
Setting      key, value (kb name, contact email, review rule any|all, bypass roles,
             allowed_ips, js_only_access, password_expiry_days, top_articles_count)
             evidence: API /settings/account, settings category   confidence: high

User         id, email (unique), first_name, last_name, role (superadmin|admin|collaborator|
             draft_writer|viewer), active, password_hash, last_sign_in_at, created_at, updated_at
             evidence: API /users, roles article   confidence: high

Group        id, name, auto_join_domains (email extensions), created_at
GroupMember  group_id, user_id
             evidence: API /groups (smart_load, auto_groups)   confidence: high

Category     id, parent_id (nullable), name, slug (codename), description,
             accessibility (public|internal|private), archived, position
             evidence: API /categories   confidence: high (position: guess, implied by drag-drop)

Article      id, slug (codename), accessibility (public|internal|private|url_only),
             main_category_id, created_by_id, views, upvotes, downvotes, archived_at,
             created_at, updated_at
ArticleCategory  article_id, category_id   ("also in" categories)
             evidence: API /articles category_ids, "display in multiple categories"   confidence: high

ArticleVersion  id, article_id, number, language (en_US), title, subtitle(description),
             status (draft|published), is_default, publish_at, expire_at, current_revision_id
             evidence: versions article, auto-publish/expiry article   confidence: high

Revision     id, version_id, body, body_format (html|markdown), body_text (plain, for search),
             author_id, autosave (bool), created_at
             evidence: versions article, API answer{body, body_txt, format}   confidence: high

Keyword      id, name;  ArticleKeyword  article_id, keyword_id
             evidence: API keywords, "What are keywords"   confidence: high

Access       subject (article|category), subject_id, user_id | group_id
             evidence: API user_ids/group_ids on private content   confidence: high

Review       id, version_id, requested_by_id, note, status (pending|approved|changes_requested), created_at
ReviewAssignment  review_id, reviewer (user|group), decision, message, decided_at
             evidence: review process article   confidence: medium

Comment      id, version_id, author_id, anchor (text range), body, resolved, created_at
             evidence: commenting article, webhook comment_*   confidence: medium

Upload       id, filename, content_type, size, sha256, uploaded_by_id, created_at  (bytes in DB or on disk)
             evidence: files manager, backups uploads_count   confidence: high

SearchEvent  id, query, normalized, results_count, outcome (found|dead_end|bounced),
             clicked_article_id, source (kb|widget|api), page_context, user_id?, created_at
ViewEvent    id, article_id, version_id, source, seconds_spent, read (bool), created_at
Vote         article_id, value (+1|-1), comment?, created_at
             evidence: analytics API metrics   confidence: high

ContactRequest  id, name, email, subject, body, search_query?, created_at
             evidence: contact form settings   confidence: medium

ApiKey       id, name, token_hash, created_by_id, last_used_at, revoked_at
Webhook      id, url, event, secret, enabled, last_response_code, created_by_id
WebhookDelivery  id, webhook_id, activity_id, attempt, status_code, next_retry_at
             evidence: API /webhooks   confidence: high (secret + retries are ours: original documents neither)

Activity     id, trackable_type, trackable_id, owner_id, action, extra (json), automatic, created_at
             evidence: API /activities, webhook payload   confidence: high

ContextRule  id, url_pattern, article_ids (ordered)   (ours: page → suggested articles for the widget)
             evidence: none in original docs. Our addition for F04.   confidence: guess
```

Relationships: Category 1-n Category (tree). Article n-n Category (one main).
Article 1-n ArticleVersion 1-n Revision. Article n-n Keyword. Article/Category
n-n User|Group via Access. User n-n Group. ArticleVersion 1-n Review 1-n
ReviewAssignment. ArticleVersion 1-n Comment. Article 1-n ViewEvent/Vote.
Webhook 1-n WebhookDelivery. Every write → Activity → webhooks.

## Feature matrix

See `features.csv`. Must: 30, should: 22, could: 12, skip: 9.

## Out of scope (cannot or should not be cloned)

- **Swifty AI chatbot / AI answers / AI subtitle & keywords / AI article requests.** These need an LLM provider, which breaks "in a box". Could be added later behind a config flag.
- **Helpjuice's integrations marketplace (300+)**. That's their partner network. We get the API and webhooks instead.
- **Liquid/Shopify template engine** for theming. We use our own templates plus custom CSS.
- **LDAP, ADFS, Active Directory**. OIDC SSO covers Okta/Azure/Google later.
- **Custom SSL upload, custom domain management**. A reverse proxy or the host handles these.
- **Sharing access between multiple accounts**. Single tenant.
- **Helpjuice's copy, theme, logos, help content.** Our own articles come in through our own export.
- **Billing / subscription**. It's internal.
- **Their hosting, SLA, backups service**. We get one file to back up.

## Size

Screens 23, flows 10, entities ~22. Hard parts:

1. **The article editor.** WYSIWYG + markdown, custom blocks and autosave, with no CDN and no npm build. It's the single biggest piece.
2. **Versions, revisions and review together.** A draft on top of a published version, scheduled publish/expire, approval rules.
3. **The embed widget.** It needs to be tiny, self-hosted, work inside our app (CSP, cookies, SPA route changes), give page-aware suggestions and handle internal content safely.
4. Search quality on SQLite FTS5 (typo tolerance, keyword boosting, highlighting).
5. Helpjuice import (rate limits, image rehosting, link rewriting).

Size: **L** (a quarter) for everything here. A must-only first release
(editor, versions, categories, permissions, search, widget, API, import) is
**M** (a few weeks).

---

# Part 2: Support desk (Intercom slice)

Scope: Intercom's **Messenger** (conversations and tickets inside the widget),
**Inbox** (shared team inbox), **Tickets** (customer, back-office, tracker),
assignment, macros, SLAs with office hours, email, and support reports. Built
into the same binary and database as Part 1, with the same widget and the same
`users` as agents.
Terms: Intercom's terms weren't reviewed, and no Intercom account was used.
This part comes from Intercom's public developer docs and help center only.

## Sources

| # | source | URL | notes |
| --- | --- | --- | --- |
| 15 | Conversation object (API) | https://developers.intercom.com/docs/references/rest-api/api.intercom.io/conversations/conversation | states, priority, assignees, waiting_since, SLA, statistics, parts |
| 16 | Ticket object (API) | https://developers.intercom.com/docs/references/rest-api/api.intercom.io/tickets/ticket | categories, ticket_state, ticket_type, attributes, is_shared, linked objects |
| 17 | Ticket type attributes (API) | https://developers.intercom.com/docs/references/rest-api/api.intercom.io/ticket-type-attributes/createtickettypeattribute | data types, required/visible flags for agents vs contacts |
| 18 | Ticket states | https://www.intercom.com/help/en/articles/8687982-ticket-states-explained-beta | 4 state categories, internal vs customer labels, notify toggle |
| 19 | Custom ticket types | https://intercom.com/help/en/articles/7112127-create-custom-ticket-types | category visibility rules |
| 20 | Round robin | https://www.intercom.com/help/en/articles/6512504-assign-conversations-evenly-using-round-robin | round robin vs balanced, away status, limits |
| 21 | SLAs and office hours | https://www.intercom.com/help/en/articles/9263617-slas-and-office-hours | timers count office hours only, holidays |
| 22 | Messenger JS methods | https://developers.intercom.com/installing-intercom/web/methods | spaces: home, messages, help, tickets. JWT identity. |
| 23 | Third-party explainers | https://www.getmacha.com/blog/intercom-tickets-explained, https://www.getmacha.com/blog/intercom-shared-inbox-explained, https://www.eesel.ai/blog/intercom-sla-rules | secondary. Used only where official docs were silent (tracker behaviour, views, FRT/NRT definitions). |

## Core loop (support)

Someone in our app opens Help, doesn't find an answer, and asks. The right
agent picks it up from the shared inbox, replies (often with an article), and
the customer sees the answer in the widget or by email. It gets resolved and
rated, and the gap feeds back into the knowledge base.

## Screens

Customer side (inside the S07 widget, plus email):

| ID | screen | route / how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S24 | widget home | widget opens | entry: ask, see open conversations, search help | "Ask a question" button, recent conversations with unread dot, reply-time expectation, help search | no conversations, unread, office closed |
| S25 | new request | widget → Ask | write the question or pick a ticket type form | message box, live article suggestions as you type, ticket type picker, custom fields, attachments | typing, suggestions shown, required field missing, sending |
| S26 | conversation (customer) | widget → a conversation | the thread | messages, agent name/avatar, typing indicator, attachments, article cards, "we'll reply by…", rating at close | waiting, agent typing, replied, closed, rated, offline |
| S27 | my tickets | widget → Tickets | track longer requests | list with customer-facing state labels, ticket detail with shared fields and timeline | none, submitted, in progress, waiting on you, resolved |
| S28 | notification email | email | reply without opening the app | message, "reply above this line", link back to the widget | first reply, follow-up, resolved, rating request |

Agent side (admin app):

| ID | screen | route / how to reach | purpose | key components | states seen |
| --- | --- | --- | --- | --- | --- |
| S29 | inbox | `/admin/inbox` | work the queue | left: views (Your inbox, Mentions, Unassigned, team inboxes, custom views) with counts · middle: list (contact, preview, waiting time, SLA timer, priority) · right: thread | empty view, many, SLA breaching, filtered |
| S30 | thread + composer | inbox → a conversation | answer | message list, reply/note toggle, macros, insert article (by code), attachments, assign/snooze/close/priority, "Lee is replying" collision warning | new, assigned, note, snoozed, closed, reopened |
| S31 | details sidebar | inside S30 | context | contact (name, role patient/staff, external id), company/practice, page they wrote from, articles they read first, past conversations, ticket fields, linked tickets, tags | unknown contact, verified contact |
| S32 | ticket view | inbox → a ticket | structured request | type, state (internal label), required fields, shared-with-customer toggle, linked conversations/tickets | each state, missing required field |
| S33 | tracker ticket | `/admin/tickets/:id` (tracker) | one issue, many customers | linked conversations list, "notify all linked" on resolve | open, resolved with notifications sent |
| S34 | contacts | `/admin/contacts`, `/admin/contacts/:id` | who writes in | table, search, profile with conversations/tickets, attributes from our app | empty, filled, merged |
| S35 | macros | `/admin/macros` | saved replies | list, editor with variables ({{first_name}}) and actions (tag, assign, close) | empty, filled |
| S36 | ticket types & states | `/admin/settings/tickets` | configure forms | type list (category, icon), attribute editor (data type, required for agents/customers, visible to customer), state list (category, internal/customer labels, notify toggle) | default, custom, archived |
| S37 | teams & assignment | `/admin/settings/teams` | routing | teams, members, method (manual, round robin, balanced), per-agent limit, away status | - |
| S38 | SLAs & office hours | `/admin/settings/sla` | targets | office hours per team with time zone, holidays, SLA rules (first response, next response, time to close) with conditions | - |
| S39 | rules | `/admin/settings/rules` | simple automation | "when [new conversation / ticket created / customer replied] and [conditions] then [assign, tag, priority, SLA, auto-reply]" | empty, filled, disabled |
| S40 | support reports | `/admin/reports/support` | performance | volume, median first response, resolution time, SLA hit rate, CSAT, by team/agent/page/topic, "asked after reading article X" | empty, filled |
| S41 | email channel | `/admin/settings/email` | support address | forwarding address, verified sending domain, signature, auto-reply out of hours | unverified, verified, bouncing |
| S42 | access log | `/admin/audit` | HIPAA access trail | who viewed/changed/exported which conversation or contact, filters, export | empty, filled |

## Flows

```
F11 Customer asks from the widget              (the support core loop)
    S07/S24 Ask -> S25 types question -> article suggestions shown ->
      (a) opens article, done: logged as deflected
      (b) sends -> S26 waiting -> agent replies (S30) -> S26 live / S28 email ->
          customer replies -> agent closes -> rating
    happy path clicks: 3 to send (Help, Ask, Send)
    edge: offline/out of office hours, attachment too big, contact not identified,
          customer replies after close (reopens), reply by email instead of widget

F12 Agent works the queue
    S29 Unassigned or Your inbox -> open -> assign to me (or auto-assigned) -> S30 reply
      with macro or article -> close | snooze until X | set priority
    happy path clicks: ~4
    edge: two agents open the same one (collision), assigned agent goes away,
          snooze expires, customer replies while snoozed (unsnoozes)

F13 Customer submits a ticket form
    S25 picks "Billing question" type -> fills invoice number (required for customers) -> submit ->
    S27 shows "Submitted" -> agent moves to In progress -> Waiting on customer (customer notified) ->
    customer replies -> Resolved (customer notified)
    edge: state with notify off, customer reply on a resolved ticket, type changed mid-way

F14 Back-office hand-off
    S30 conversation -> "Create back-office ticket" for Billing team, linked -> billing works it
    in S32 (customer can't see it) -> resolved -> original agent notified -> replies to customer
    edge: hand-off team has no one on shift, ticket shared with customer by mistake (needs a setting)

F15 Tracker: one incident, many customers
    agent sees several "can't log in" conversations -> creates tracker ticket (S33) ->
    links conversations -> fixes -> resolves tracker -> "notify all linked" posts an update to each
    edge: some linked conversations already closed, customer has no email

F16 Email in, email out
    customer emails support@ -> conversation created (contact matched by email) -> agent replies ->
    email threaded by Message-ID/In-Reply-To -> customer replies by email -> appended
    edge: unknown sender, auto-replies/loops, forwarded chains, attachments, bounces

F17 SLA at risk
    rule applies "first response 4 office hours" to billing conversations -> timer in S29 list ->
    goes amber at 75% -> breach marks missed, and the conversation sorts to the top of "SLA at risk" view
    edge: office closed, holiday, customer is the last to reply (next-response clock), SLA removed

F18 Close the loop with the knowledge base   (ours: Intercom has nothing like this for an external KB)
    S30 resolved conversation -> "Draft article from this" -> S12 editor prefilled with the question as title
    and the answer as body (PHI stripped by the agent) -> review -> publish -> linked dead-end searches marked covered

F19 Configure a ticket type
    S36 -> new type "Billing question" (customer) -> add fields (invoice number: string, required for customers;
    amount: decimal; screenshots: files) -> pick states -> save -> appears in S25

F20 Compliance review
    S42 -> filter by contact -> see every view, change and export of their conversations, with who/when/IP -> export
```

## Components (new, beyond Part 1)

| component | variants | states | used on |
| --- | --- | --- | --- |
| Message bubble | customer, agent, internal note (tinted), system event (assigned, state changed), article card | sending, sent, failed, edited | S26, S30, S32 |
| Composer | reply / note toggle, macro picker (`#`), article picker (`/` or code), mention (`@`), attachments | empty, typing, sending, collision warning | S30 |
| Conversation row | unread, assigned avatar, SLA timer, priority flag, channel icon, waiting time | selected, unread, breaching | S29 |
| View list | system views, team inboxes, custom views, with counts | active, empty | S29 |
| SLA timer | on track, at risk, missed, paused (out of hours) | - | S29, S30 |
| State pill (ticket) | submitted, in progress, waiting on customer, resolved: internal and customer labels | - | S27, S29, S32 |
| Assignee picker | people, teams, "me", unassign | away members dimmed | S30, S32 |
| Typing / presence indicator | agent typing (customer side), "Lee is viewing/replying" (agent side) | - | S26, S30 |
| Rating prompt | 5-point + comment | rated | S26, S28 |
| Field editor | string, list, integer, decimal, boolean, datetime, files | required, invalid | S25, S32, S36 |
| Condition builder | attribute, operator, value, and/or | invalid | S38, S39 |

## Inferred data model (new)

```
Contact      id, external_id (from our app's token `sub`), email, name, kind (patient|staff|unknown),
             company_id, attributes (json), last_seen_at, created_at
             evidence: API contacts on conversation/ticket, Messenger JWT user_id   confidence: high
Company      id, external_id, name, attributes (json)     (= a practice/clinic in our world)
             evidence: API company on conversation   confidence: medium

Team         id, name, assignment (manual|round_robin|balanced), assignment_limit, office_hours_id
TeamMember   team_id, user_id;  users gain: availability (active|away)
             evidence: team_assignee_id, round robin article   confidence: high

Conversation id, contact_id, channel (widget|email|api), title, state (open|snoozed|closed),
             priority (none|low|medium|high|urgent), assignee_user_id, assignee_team_id,
             snoozed_until, waiting_since, page_context, first_response_at, closed_at,
             rating, rating_comment, created_at, updated_at
             evidence: API Conversation object   confidence: high
Ticket       id, number (shown to humans), ticket_type_id, category (customer|back_office|tracker),
             state_id, attributes (json, validated against the type), is_shared, contact_id?,
             assignee_user_id, assignee_team_id, open, snoozed_until, created_at
             evidence: API Ticket object   confidence: high
             (modelling choice for architect: one `threads` table with kind conversation|ticket,
              since both have parts, assignees, snooze and state, vs two tables)
Part         id, thread_id, author (contact|user|system), kind (comment|note|assignment|state_change|
             priority|snooze|close|open|rating|article), body, email_message_id, created_at, edited_at
             evidence: conversation_parts / ticket_parts   confidence: high
ThreadLink   from_thread_id, to_thread_id, kind (handoff|tracker)
             evidence: linked_objects   confidence: high

TicketType   id, name, category, icon, description, archived
TicketTypeAttribute  id, type_id, name, data_type (string|list|integer|decimal|boolean|datetime|files),
             options (json, for list), required_for_agents, required_for_contacts, visible_to_contacts, position
TicketState  id, category (submitted|in_progress|waiting_on_customer|resolved), internal_label,
             external_label, notify_customer, archived
TicketTypeState  type_id, state_id
             evidence: ticket type attribute API, ticket states article   confidence: high

Tag          id, name;  ThreadTag thread_id, tag_id
Macro        id, name, body (with variables), actions (json), visibility (personal|team|all), created_by
             evidence: macros (formerly saved replies)   confidence: medium
OfficeHours  id, name, timezone, weekly (json), holidays (json)
SlaRule      id, name, conditions (json), first_response_s, next_response_s, time_to_close_s, office_hours_only
SlaTimer     thread_id, rule_id, kind (first_response|next_response|close), due_at, status (active|hit|missed|cancelled)
             evidence: sla_applied, SLAs and office hours article   confidence: high
Rule         id, trigger, conditions (json), actions (json), position, enabled
             evidence: assignment rules, workflows (simplified)   confidence: medium
Mention / Notification  user_id, thread_id, part_id, kind, read_at
EmailMessage message_id, thread_id, part_id, in_reply_to, direction, status (sent|bounced|received)
             evidence: email channel (needed for threading)   confidence: high (ours)
AuditEvent   id, actor_user_id, action (view|update|export|delete), subject_type, subject_id, ip, at
             evidence: none in Intercom docs. HIPAA requirement.   confidence: high (ours)
Attachment   reuses `uploads`, with a private flag (support attachments are never public)
```

Relationships: Contact n-1 Company. Contact 1-n Conversation/Ticket. Thread
1-n Part. Thread n-n Thread via ThreadLink (hand-off, tracker). TicketType n-n
TicketState, 1-n TicketTypeAttribute. Team n-n User. Thread 1-n SlaTimer.
Part 1 links: Conversation → page_context and search_event (what they searched
before asking), Part → article (inserted articles), Conversation → draft
article (F18).

## Compliance (new: PHI is now in the system)

Conversations, tickets, attachments and contact records will hold PHI. Things
that change for the whole of helpvibe:

- **BAAs** with every processor that touches ticket data: the host, the email provider (inbound and outbound), and backup storage. Pick vendors that sign BAAs.
- **Encryption at rest**: the SQLite file, the uploads inside it, and every backup. Options: an encrypted volume on the host (simplest), or SQLCipher (encrypted SQLite) for file-level encryption. Decided in architect.
- **Access log** (S42) of every view, change and export of PHI-bearing records, kept 6 years.
- **Minimum necessary**: agents only see teams' inboxes they belong to, and contact fields can be hidden by role.
- **Auth hardening moves up**: SSO (OIDC) and two-factor become must-haves for agents, with idle sign-out at 15 minutes.
- **Retention**: configurable auto-delete of closed conversations after N years, plus delete/export of one contact's data.
- **Search analytics**: stop storing raw widget queries tied to identified people (closes the S19-3 question).
- **Emails carry PHI**: notification emails can either include the message or only say "you have a reply" with a link. A setting, default "link only" for patients.

## Feature matrix

New rows in `features.csv` (areas prefixed `support-`): must 23, should 17,
could 3, skip 6. Plus 3 auth rows driven by PHI: SSO promoted to must, and
two-factor and idle sign-out added. **Whole matrix now: must 56, should 39,
could 14, skip 15 (124 rows).**

## Out of scope (Part 2)

- **Fin AI agent, Copilot, AI topics/summaries, monitors and scorecards (AI QA).** Need an external LLM, and with PHI also a BAA. Could come later.
- **Outbound**: product tours, banners, checklists, news, series, campaign emails.
- **Phone/voice, SMS, WhatsApp, social channels, Slack Connect.**
- **Intercom's app store and integrations marketplace.** Our API and webhooks instead.
- **Sales features** (sales agent, lead qualification), **group conversations** with several customers.
- **Their data platform** (custom objects, CDP sync), beyond contact attributes passed from our app.

## Size (Part 2, and the whole)

Part 2: screens 19 (S24–S42), flows 10 (F11–F20), entities ~22. Hard parts:

1. **Realtime**: WebSockets for new messages, typing, presence, collision warnings, live counts in views. Axum handles it, but it's the first stateful part of the server.
2. **Email in**: receiving mail needs a provider that posts inbound mail to us (with a BAA), threading by headers, loop/auto-reply detection and bounces. This is the one place "in a box" leans on an outside service.
3. **PHI compliance**: encryption at rest, access logging on every read, retention, and SSO/2FA, spread across the whole app rather than one feature.
4. SLA clocks with office hours, holidays and pauses, computed correctly and cheaply.
5. Assignment under concurrency (round robin/balanced with limits and away status) without double-assigning.

Size: Part 2 alone is **L** (a quarter). Part 1 + Part 2 together is **XL**,
so rescope into phases:

- **Phase 1**: help center, editor and widget (Part 1 must-haves). M.
- **Phase 2**: support MVP. Conversations from the widget, inbox with views and assignment, notes, macros, article insert, email in and out, contacts, one ticket type with states, access log, SSO and 2FA, encryption at rest. M to L.
- **Phase 3**: ticket types with custom fields, back-office and tracker tickets, SLAs with office hours, rules, round robin/balanced, CSAT, reports, F18 article drafting. M.

---

# Part 3: Ticketing (Intercom tickets), a separate product

Decision 2026-11-04: the admin becomes **two products**, **Knowledge base**
(Helpjuice, Part 1) and **Helpdesk** (Intercom: conversations from Part 2 +
tickets here). They share only people, sign-in and the widget, and can be
merged later.

## Sources (added)

| # | source | URL | notes |
| --- | --- | --- | --- |
| 24 | Custom ticket types | https://intercom.com/help/en/articles/7112127-create-custom-ticket-types | categories, default + custom attributes, customer/teammate settings, limits |
| 25 | Tickets explained | https://www.intercom.com/help/en/articles/6436600-tickets-explained | the three categories |
| 26 | Back-office tickets | https://www.intercom.com/help/en/articles/8300297-how-to-create-a-back-office-ticket | created from a conversation, linked, one shareable per conversation |
| 27 | Customer (tickets) portal | https://www.intercom.com/help/en/articles/8450754-customer-portal-explained | customers' list of their tickets |
| 28 | Ticket states | (source 18) | 4 categories, internal/external labels, notify toggle |
| 29 | Community: convert conversations | https://community.intercom.com/helpdesk-9/auto-convert-conversations-to-tickets-6719 | conversion is manual. Customers start in a conversation or a ticket form. |

## Rules found (Intercom's behaviour we replicate)

- **Customer tickets:**
  - Always shared with the customer, who sees the state's customer-facing label and the fields marked visible.
  - Both sides can reply, and agents can add internal notes.
  - Customers can't edit fields after submitting.
- **Back-office tickets:**
  - Internal unless the type is shareable.
  - Created from a conversation and linked to it.
  - Customer replies stay in the linked conversation.
- **Tracker tickets:** always internal, and many conversations link to one.
- **Default fields:** every type has a title and a description, each optionally visible to and required for customers.
- **Custom fields:**
  - Formats: text (single or multi-line), list, whole number, decimal, yes/no, date-time, file. The format is fixed once created.
  - Each field can be visible to customers and required for customers (customer tickets, or shareable back-office ones).
  - Each field can be hidden from the agent creation form, required when an agent creates the ticket, or required before closing.
  - Fields are archived, never deleted. At most 50 per type.
- **Changing type:** only to another type of the same category.
- **States:**
  - Each type uses at least one state from each category: submitted, in progress, waiting on customer, resolved.
  - Moving into a state notifies the customer (email and widget) when that state has notify switched on.

## Screens (added)

| ID | screen | route | purpose | states |
| --- | --- | --- | --- | --- |
| S43 | product switcher | admin sidebar | Knowledge base or Helpdesk | - |
| S44 | tickets list | `/admin/tickets` | all tickets, filter by type, state, assignee, category | empty, filtered |
| S45 | new ticket (agent) | `/admin/tickets/new` | pick type, fill fields, contact, assignee | missing required |
| S46 | ticket page | `/admin/threads/:n` (kind ticket) | replies, notes, state, fields, links | each state, close blocked by required field |
| S47 | ticket types | `/admin/ticket_types` | list, create, archive | default types |
| S48 | ticket type editor | `/admin/ticket_types/:id/edit` | name, category, description, fields, states | - |
| S49 | ticket states | `/admin/ticket_states` | labels, notify, archive | - |
| S50 | widget: submit a request | widget → Ask us → type | customer ticket form | required missing |
| S51 | widget: your tickets | widget → Your conversations | tickets with customer-facing state | - |

## Flows (added)

```
F21 Customer submits a ticket from the widget
    S07 -> Ask us -> S50 pick "Billing question" -> fill visible fields -> submit -> S51 "Submitted"
    happy path clicks: 4
    edge: required field empty, decimal with a comma, no customer ticket types (falls back to a conversation)

F22 Agent works a ticket
    S44 -> S46 -> set state In progress -> reply -> Waiting on customer (customer emailed) -> customer replies -> Resolved
    edge: required-to-close field empty, state with notify off, reopened by a customer reply

F23 Convert a conversation into a customer ticket
    S30 -> "Convert to ticket" -> type -> fields -> the conversation becomes the ticket (history kept)

F24 Hand off to another team
    S30 -> "Back-office ticket" -> type, team -> linked; billing works it; customer only sees the conversation

F25 Track one issue across customers
    tracker ticket -> link conversations -> resolve -> optional update posted to each linked conversation
```

## Data model (extends Part 2)

Already in the schema (Part 2 migration): `ticket_types`, `ticket_type_attributes`, `ticket_states`,
`ticket_type_states`, `threads` (kind = 'ticket', ticket_type_id, ticket_state_id, ticket_attributes, is_shared),
`thread_links` (handoff | tracker). Adds:

```
TicketTypeAttribute + multiline (bool), required_to_close (bool), hidden_on_create (bool)
                    evidence: source 24   confidence: high
SupportThread (ticket)  title = default title attribute; ticket_attributes["description"] = default description
```

## Out of scope (Part 3)

- **AI autofill of title and description (Fin):** needs an LLM.
- **Conditional fields** (show a field only when another has a value).
- **CSV import of list options.**
- **A separate customer portal on a custom domain:** the widget's list plus the email links cover it.
- **Company-wide ticket visibility:** needs companies (M8).

## Size (Part 3)

9 screens, 5 flows, no new tables (3 new columns). Hard parts:
1. Validating fields by type and by who's editing.
2. State changes triggering customer notifications.
3. Keeping internal and shared content apart for back-office and tracker tickets.

Size: **S–M**, because most of the plumbing (threads, parts, email, widget, live updates) exists from Part 2.
