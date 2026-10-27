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
      status = statuses_named(name).first || status_class.new(name: name)
      status.is_closed = true
      status.position ||= status_class.maximum(:position).to_i + 1
      status.csys_closed_outcome = outcome
      status.csys_maturity = maturity
      status.save!
    end

    REQUIREMENT_MATURITY.each do |name, maturity|
      statuses_named(name).update_all(csys_maturity: maturity)
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

  def statuses_named(name)
    status_class.where(status_class.arel_table[:name].lower.eq(name.downcase))
  end

  def workflow_class
    @workflow_class ||= Class.new(ActiveRecord::Base) do
      self.table_name = 'workflows'
      self.inheritance_column = :_disabled_type
    end
  end

  def ensure_rejection_transitions
    rejected_id = statuses_named('Rejected').pick(:id)
    tracker_ids = requirement_tracker_ids
    role_ids = ordinary_role_ids
    old_status_ids = status_class.pluck(:id)

    tracker_ids.product(role_ids, old_status_ids).each do |tracker_id, role_id, old_status_id|
      insert_transition(tracker_id, role_id, old_status_id, rejected_id)
    end
  end

  def ensure_rejected_recovery_transitions
    rejected_id = statuses_named('Rejected').pick(:id)
    draft_id = statuses_named('Draft').pick(:id)
    return unless rejected_id && draft_id

    tracker_ids = requirement_tracker_ids
    role_ids = ordinary_role_ids

    tracker_ids.product(role_ids).each do |tracker_id, role_id|
      insert_transition(tracker_id, role_id, rejected_id, draft_id)
    end
  end

  # Ordinary roles receive the workflow transition, while Redmine's own
  # edit-issue permission remains the authorization gate. This avoids coupling
  # the item-profile contract to translated or locally renamed role names.
  def ensure_erased_transitions
    erased_id = statuses_named('Erased').pick(:id)
    return unless erased_id

    tracker_ids = requirement_tracker_ids
    role_ids = ordinary_role_ids
    old_status_ids = status_class.pluck(:id)

    tracker_ids.product(role_ids, old_status_ids).each do |tracker_id, role_id, old_status_id|
      insert_transition(tracker_id, role_id, old_status_id, erased_id)
    end
  end

  # The same roles may recover an Erased requirement back to Draft,
  # restoring its identity, hierarchy and relations (a non-destructive model).
  def ensure_erased_recovery_transitions
    erased_id = statuses_named('Erased').pick(:id)
    draft_id = statuses_named('Draft').pick(:id)
    return unless erased_id && draft_id

    tracker_ids = requirement_tracker_ids
    role_ids = ordinary_role_ids

    tracker_ids.product(role_ids).each do |tracker_id, role_id|
      insert_transition(tracker_id, role_id, erased_id, draft_id)
    end
  end

  def requirement_tracker_ids
    tracker_class = Class.new(ActiveRecord::Base) { self.table_name = 'trackers' }
    tracker_class.where(csys_item_kind: 'requirement').pluck(:id)
  end

  def ordinary_role_ids
    role_class = Class.new(ActiveRecord::Base) { self.table_name = 'roles' }
    role_class.where(builtin: 0).pluck(:id)
  end

  def insert_transition(tracker_id, role_id, old_status_id, new_status_id)
    workflow_class.find_or_create_by!(
      type: 'WorkflowTransition', tracker_id: tracker_id, role_id: role_id,
      old_status_id: old_status_id, new_status_id: new_status_id,
      author: false, assignee: false
    )
  end
end
