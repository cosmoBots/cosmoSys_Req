class CreateCosmosysRequirements < ActiveRecord::Migration[6.1]
  REQUIREMENT_COLUMNS = {
    rq_type: :string,
    rq_level: :string,
    rq_rationale: :text,
    rq_srcs: :text,
    rq_var: :string,
    rq_value: :string,
    rq_verif_methods: :text,
    rq_verif_description: :text,
    rq_compl_state: :string,
    rq_compl_justif: :text,
    rq_implem_progress: :string,
    rq_deriv_src_id: :bigint
  }.freeze

  # Development schemas may still contain the columns created by an earlier
  # rewrite of this same base migration. They are deliberately removed rather
  # than aliased: this project is still in its regenerable-schema phase and the
  # compact rq_* vocabulary is the only supported contract.
  OBSOLETE_REQUIREMENT_COLUMNS = %i[
    requirement_type requirement_level requirement_rationale requirement_sources
    requirement_variable requirement_value requirement_verification_methods
    requirement_verification_description requirement_compliance_state
    requirement_compliance_justification requirement_implementation_progress
    requirement_derivation_source_id
  ].freeze

  TRACKERS = [
    ['requirement', 'csRq'],
    ['requirement_management', 'csRqm'],
    ['requirement_release', 'csRqr'],
    ['requirement_management_release', 'csRqmr']
  ].freeze

  def up
    OBSOLETE_REQUIREMENT_COLUMNS.reverse_each do |name|
      remove_column :issues, name if column_exists?(:issues, name)
    end

    REQUIREMENT_COLUMNS.each do |name, type|
      add_column :issues, name, type unless column_exists?(:issues, name)
    end
    add_index :issues, :rq_type unless index_exists?(:issues, :rq_type)
    add_index :issues, :rq_level unless index_exists?(:issues, :rq_level)
    add_index :issues, :rq_compl_state unless index_exists?(:issues, :rq_compl_state)
    add_index :issues, :rq_implem_progress unless index_exists?(:issues, :rq_implem_progress)
    add_index :issues, :rq_deriv_src_id unless index_exists?(:issues, :rq_deriv_src_id)

    draft = ensure_status('Draft', closed: false)
    stable = ensure_status('Stable', closed: false)
    approved = ensure_status('Approved', closed: true)

    tracker_ids = TRACKERS.map do |key, name|
      tracker = tracker_class.find_by(csys_key: key) || tracker_class.where(tracker_class.arel_table[:name].lower.eq(name.downcase)).first || tracker_class.new
      tracker.assign_attributes(name: name, csys_key: key, csys_item_kind: 'requirement', default_status_id: draft.id)
      tracker.save!
      reset_requirement_workflow(tracker.id, draft.id, stable.id, approved.id)
      tracker.id
    end
    issues = issue_class.where(tracker_id: tracker_ids)
    issues.update_all(status_id: draft.id)
    {
      rq_type: 'complex', rq_level: 'system',
      rq_compl_state: 'to_be_confirmed', rq_verif_methods: '["to_be_defined"]'
    }.each do |attribute, value|
      issues.where(attribute => nil).update_all(attribute => value)
    end
    if table_exists?(:projects_trackers) && column_exists?(:projects, :csys_project_profile)
      project_class = Class.new(ActiveRecord::Base) { self.table_name = 'projects' }
      project_class.where(csys_project_profile: 'requirements').find_each do |project|
        tracker_ids.each do |tracker_id|
          assignment_class.find_or_create_by!(project_id: project.id, tracker_id: tracker_id)
        end
      end
    end
  end

  def down
    TRACKERS.reverse_each do |key, _name|
      tracker = tracker_class.find_by(csys_key: key)
      next unless tracker

      workflow_class.where(tracker_id: tracker.id).delete_all if table_exists?(:workflows)
      unless issue_class.where(tracker_id: tracker.id).exists?
        assignment_class.where(tracker_id: tracker.id).delete_all
        tracker.destroy!
      end
    end

    REQUIREMENT_COLUMNS.keys.reverse_each do |name|
      remove_column :issues, name if column_exists?(:issues, name)
    end
  end

  private

  def issue_class
    @issue_class ||= Class.new(ActiveRecord::Base) { self.table_name = 'issues' }.tap(&:reset_column_information)
  end

  def assignment_class
    @assignment_class ||= Class.new(ActiveRecord::Base) do
      self.table_name = 'projects_trackers'
      self.primary_key = nil
    end
  end

  def workflow_class
    @workflow_class ||= Class.new(ActiveRecord::Base) do
      self.table_name = 'workflows'
      self.inheritance_column = :_disabled_type
    end
  end

  def tracker_class
    @tracker_class ||= Class.new(ActiveRecord::Base) { self.table_name = 'trackers' }.tap(&:reset_column_information)
  end

  def status_class
    @status_class ||= Class.new(ActiveRecord::Base) { self.table_name = 'issue_statuses' }.tap(&:reset_column_information)
  end

  def ensure_status(name, closed:)
    status = status_class.where(status_class.arel_table[:name].lower.eq(name.downcase)).first || status_class.new
    status.name = name
    status.is_closed = closed
    status.position ||= status_class.maximum(:position).to_i + 1
    status.save!
    status
  end

  def reset_requirement_workflow(tracker_id, draft_id, stable_id, approved_id)
    return unless table_exists?(:workflows)

    workflow_class.where(tracker_id: tracker_id).delete_all
    role_class = Class.new(ActiveRecord::Base) { self.table_name = 'roles' }
    role_ids = role_class.where(builtin: 0).pluck(:id)
    transitions = [
      [draft_id, draft_id], [draft_id, stable_id],
      [stable_id, draft_id], [stable_id, stable_id], [stable_id, approved_id],
      [approved_id, stable_id], [approved_id, approved_id]
    ]
    role_ids.each do |role_id|
      transitions.each do |old_status_id, new_status_id|
        workflow_class.create!(
          type: 'WorkflowTransition', tracker_id: tracker_id, role_id: role_id,
          old_status_id: old_status_id, new_status_id: new_status_id,
          author: false, assignee: false
        )
      end
    end
  end
end
