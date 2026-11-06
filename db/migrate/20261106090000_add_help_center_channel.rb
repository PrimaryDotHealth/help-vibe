# Questions and requests sent from the help center's Contact page.
class AddHelpCenterChannel < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      alter table threads drop constraint threads_channel_check;
      alter table threads add constraint threads_channel_check
        check (channel = any (array['widget', 'email', 'api', 'internal', 'help_center']));
      alter table thread_parts drop constraint thread_parts_channel_check;
      alter table thread_parts add constraint thread_parts_channel_check
        check (channel = any (array['widget', 'email', 'api', 'admin', 'system', 'help_center']));
    SQL
  end

  def down
    execute <<~SQL
      update thread_parts set channel = 'widget' where channel = 'help_center';
      update threads set channel = 'widget' where channel = 'help_center';
      alter table threads drop constraint threads_channel_check;
      alter table threads add constraint threads_channel_check
        check (channel = any (array['widget', 'email', 'api', 'internal']));
      alter table thread_parts drop constraint thread_parts_channel_check;
      alter table thread_parts add constraint thread_parts_channel_check
        check (channel = any (array['widget', 'email', 'api', 'admin', 'system']));
    SQL
  end
end
