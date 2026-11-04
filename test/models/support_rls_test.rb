require "test_helper"

# The row-level-security policies, checked as a non-owner role (owners and
# superusers bypass RLS, which is why the app role in production must not own
# the tables).
class SupportRlsTest < ActiveSupport::TestCase
  self.use_transactional_tests = true

  setup do
    conn = ActiveRecord::Base.connection
    conn.execute("do $$ begin create role hv_rls_test nologin; exception when duplicate_object then null; end $$")
    conn.execute("grant select on all tables in schema public to hv_rls_test")
    @billing = Team.create!(name: "Billing")
    @billing.users << users(:two)
    @pat = Contact.for_email("pat@example.com")
    @quinn = Contact.for_email("quinn@example.com")
    @mine = SupportThread.start!(contact: @pat, body: "Pat's question", channel: "widget")
    @mine.update!(assignee_team: @billing)
    @other = SupportThread.start!(contact: @quinn, body: "Quinn's question", channel: "widget")
    @other.update!(assignee_team: Team.create!(name: "Tech"))
    @mine.note!(user: users(:two), body: "internal note")
  end

  def as_role(**settings)
    conn = ActiveRecord::Base.connection
    conn.execute("set local role hv_rls_test")
    settings.each { |k, v| conn.execute("select set_config('app.#{k}', #{conn.quote(v.to_s)}, true)") }
    yield conn
  ensure
    conn.execute("reset role")
  end

  test "no actor set: nothing" do
    as_role { |c| assert_equal 0, c.select_value("select count(*) from threads") }
  end

  test "an agent sees their team's threads, not others'" do
    as_role(actor_type: "user", user_id: users(:two).id) do |c|
      assert_equal [ @mine.id ], c.select_values("select id from threads order by id")
    end
  end

  test "a contact sees only their own thread and never notes" do
    as_role(actor_type: "contact", contact_id: @pat.id) do |c|
      assert_equal [ @mine.id ], c.select_values("select id from threads")
      assert_equal [ "Pat's question" ], c.select_values("select body from thread_parts order by id")
      assert_equal [ @pat.id ], c.select_values("select id from contacts")
    end
  end
end
