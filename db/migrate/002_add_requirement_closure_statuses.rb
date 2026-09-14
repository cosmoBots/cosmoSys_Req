class AddRequirementClosureStatuses < ActiveRecord::Migration[6.1]
  STATUSES = {
    'Approved' => ['successful', 4],
    'Erased' => ['unsuccessful', 0]
  }.freeze
  REQUIREMENT_MATURITY = {
    'Draft' => 1,
    'Stable' => 3,
    'Approved' => 4,
    'Erased' => 0
  }.freeze

  def up
    return unless column_exists?(:issue_statuses, :csys_closed_outcome)

    STATUSES.each do |name, (outcome, maturity)|
      status = status_class.where('LOWER(name) = ?', name.downcase).first || status_class.new(name: name)
      status.is_closed = true
      status.position ||= status_class.maximum(:position).to_i + 1
      status.csys_closed_outcome = outcome
      status.csys_maturity = maturity
      status.save!
    end

    REQUIREMENT_MATURITY.each do |name, maturity|
      status_class.where('LOWER(name) = ?', name.downcase).update_all(csys_maturity: maturity)
    end

    ensure_rejection_transitions
    ensure_rejected_recovery_transitions
    ensure_erased_transitions
    ensure_erased_recovery_transitions
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

  def ensure_rejected_recovery_transitions
    rejected_id = status_class.where('LOWER(name) = ?', 'rejected').pick(:id)
    draft_id = status_class.where('LOWER(name) = ?', 'draft').pick(:id)
    return unless rejected_id && draft_id

    tracker_ids = select_values("SELECT id FROM trackers WHERE csys_key IN ('requirement', 'requirement_management', 'requirement_release', 'requirement_management_release')")
    role_ids = select_values('SELECT id FROM roles WHERE builtin = 0')

    tracker_ids.product(role_ids).each do |tracker_id, role_id|
      execute <<~SQL.squish
        INSERT INTO workflows (type, tracker_id, role_id, old_status_id, new_status_id, author, assignee)
        SELECT 'WorkflowTransition', #{tracker_id}, #{role_id}, #{rejected_id}, #{draft_id}, #{connection.quoted_false}, #{connection.quoted_false}
        WHERE NOT EXISTS (
          SELECT 1 FROM workflows
          WHERE type = 'WorkflowTransition'
            AND tracker_id = #{tracker_id}
            AND role_id = #{role_id}
            AND old_status_id = #{rejected_id}
            AND new_status_id = #{draft_id}
            AND author = #{connection.quoted_false}
            AND assignee = #{connection.quoted_false}
        )
      SQL
    end
  end

  # The Developer and Manager roles may retire a requirement permanently
  # (Erased) from any prior state, mirroring the Rejected closure but scoped to
  # the roles that own the engineering content.
  def ensure_erased_transitions
    erased_id = status_class.where('LOWER(name) = ?', 'erased').pick(:id)
    return unless erased_id

    tracker_ids = select_values("SELECT id FROM trackers WHERE csys_key IN ('requirement', 'requirement_management', 'requirement_release', 'requirement_management_release')")
    role_ids = editable_role_ids
    old_status_ids = select_values('SELECT id FROM issue_statuses')

    tracker_ids.product(role_ids, old_status_ids).each do |tracker_id, role_id, old_status_id|
      insert_transition(tracker_id, role_id, old_status_id, erased_id)
    end
  end

  # Same privileged roles may recover an Erased requirement back to Draft,
  # restoring its identity, hierarchy and relations (a non-destructive model).
  def ensure_erased_recovery_transitions
    erased_id = status_class.where('LOWER(name) = ?', 'erased').pick(:id)
    draft_id = status_class.where('LOWER(name) = ?', 'draft').pick(:id)
    return unless erased_id && draft_id

    tracker_ids = select_values("SELECT id FROM trackers WHERE csys_key IN ('requirement', 'requirement_management', 'requirement_release', 'requirement_management_release')")
    role_ids = editable_role_ids

    tracker_ids.product(role_ids).each do |tracker_id, role_id|
      insert_transition(tracker_id, role_id, erased_id, draft_id)
    end
  end

  def editable_role_ids
    names = %w[developer manager]
    select_values("SELECT id FROM roles WHERE LOWER(name) IN (#{names.map { |name| connection.quote(name) }.join(', ')})")
  end

  def insert_transition(tracker_id, role_id, old_status_id, new_status_id)
    execute <<~SQL.squish
      INSERT INTO workflows (type, tracker_id, role_id, old_status_id, new_status_id, author, assignee)
      SELECT 'WorkflowTransition', #{tracker_id}, #{role_id}, #{old_status_id}, #{new_status_id}, #{connection.quoted_false}, #{connection.quoted_false}
      WHERE NOT EXISTS (
        SELECT 1 FROM workflows
        WHERE type = 'WorkflowTransition'
          AND tracker_id = #{tracker_id}
          AND role_id = #{role_id}
          AND old_status_id = #{old_status_id}
          AND new_status_id = #{new_status_id}
          AND author = #{connection.quoted_false}
          AND assignee = #{connection.quoted_false}
      )
    SQL
  end
end
