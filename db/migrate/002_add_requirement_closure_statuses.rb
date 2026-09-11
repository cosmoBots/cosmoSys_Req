class AddRequirementClosureStatuses < ActiveRecord::Migration[6.1]
  STATUSES = {
    'Approved' => 'successful',
    'Closed' => 'successful',
    'Rejected' => 'unsuccessful',
    'Erased' => 'unsuccessful'
  }.freeze

  def up
    return unless column_exists?(:issue_statuses, :csys_closed_outcome)

    STATUSES.each do |name, outcome|
      status = status_class.where('LOWER(name) = ?', name.downcase).first || status_class.new(name: name)
      status.is_closed = true
      status.position ||= status_class.maximum(:position).to_i + 1
      status.csys_closed_outcome = outcome
      status.save!
    end

    ensure_rejection_transitions
  end

  def down
    # Shared Redmine statuses may already be in use, so rollback leaves them intact.
  end

  private

  def status_class
    @status_class ||= Class.new(ActiveRecord::Base) { self.table_name = 'issue_statuses' }.tap(&:reset_column_information)
  end

  def ensure_rejection_transitions
    rejected_id = status_class.where('LOWER(name) = ?', 'rejected').pick(:id)
    tracker_ids = select_values("SELECT id FROM trackers WHERE csys_key IN ('requirement', 'requirement_management', 'requirement_release', 'requirement_management_release')")
    role_ids = select_values('SELECT id FROM roles WHERE builtin = 0')
    old_status_ids = select_values('SELECT id FROM issue_statuses')

    tracker_ids.product(role_ids, old_status_ids).each do |tracker_id, role_id, old_status_id|
      execute <<~SQL.squish
        INSERT INTO workflows (type, tracker_id, role_id, old_status_id, new_status_id, author, assignee)
        SELECT 'WorkflowTransition', #{tracker_id}, #{role_id}, #{old_status_id}, #{rejected_id}, #{connection.quoted_false}, #{connection.quoted_false}
        WHERE NOT EXISTS (
          SELECT 1 FROM workflows
          WHERE type = 'WorkflowTransition'
            AND tracker_id = #{tracker_id}
            AND role_id = #{role_id}
            AND old_status_id = #{old_status_id}
            AND new_status_id = #{rejected_id}
            AND author = #{connection.quoted_false}
            AND assignee = #{connection.quoted_false}
        )
      SQL
    end
  end
end
