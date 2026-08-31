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
      tracker = tracker_class.find_by(csys_key: key) || tracker_class.where('LOWER(name) = ?', name.downcase).first || tracker_class.new
      tracker.assign_attributes(name: name, csys_key: key, csys_item_kind: 'requirement', default_status_id: draft.id)
      tracker.save!
      reset_requirement_workflow(tracker.id, draft.id, stable.id, approved.id)
      tracker.id
    end
    execute <<~SQL.squish
      UPDATE issues
      SET status_id = #{draft.id},
          rq_type = COALESCE(rq_type, 'complex'),
          rq_level = COALESCE(rq_level, 'system'),
          rq_compl_state = COALESCE(rq_compl_state, 'to_be_confirmed'),
          rq_verif_methods = COALESCE(rq_verif_methods, '["to_be_defined"]')
      WHERE tracker_id IN (#{tracker_ids.join(', ')})
    SQL
    if table_exists?(:projects_trackers) && column_exists?(:projects, :csys_project_profile)
      tracker_ids.each do |tracker_id|
        execute <<~SQL.squish
          INSERT INTO projects_trackers (project_id, tracker_id)
          SELECT projects.id, #{tracker_id}
          FROM projects
          WHERE projects.csys_project_profile = 'requirements'
            AND NOT EXISTS (
              SELECT 1 FROM projects_trackers
              WHERE projects_trackers.project_id = projects.id
                AND projects_trackers.tracker_id = #{tracker_id}
            )
        SQL
      end
    end
  end

  def down
    TRACKERS.reverse_each do |key, _name|
      tracker = tracker_class.find_by(csys_key: key)
      next unless tracker

      execute "DELETE FROM workflows WHERE tracker_id = #{tracker.id}" if table_exists?(:workflows)
      tracker.destroy! unless select_value("SELECT 1 FROM issues WHERE tracker_id = #{tracker.id} LIMIT 1")
    end

    REQUIREMENT_COLUMNS.keys.reverse_each do |name|
      remove_column :issues, name if column_exists?(:issues, name)
    end
  end

  private

  def tracker_class
    @tracker_class ||= Class.new(ActiveRecord::Base) { self.table_name = 'trackers' }.tap(&:reset_column_information)
  end

  def status_class
    @status_class ||= Class.new(ActiveRecord::Base) { self.table_name = 'issue_statuses' }.tap(&:reset_column_information)
  end

  def ensure_status(name, closed:)
    status = status_class.where('LOWER(name) = ?', name.downcase).first || status_class.new
    status.name = name
    status.is_closed = closed
    status.position ||= status_class.maximum(:position).to_i + 1
    status.save!
    status
  end

  def reset_requirement_workflow(tracker_id, draft_id, stable_id, approved_id)
    return unless table_exists?(:workflows)

    execute "DELETE FROM workflows WHERE tracker_id = #{tracker_id}"
    role_ids = select_values('SELECT id FROM roles WHERE builtin = 0')
    transitions = [
      [draft_id, draft_id], [draft_id, stable_id],
      [stable_id, draft_id], [stable_id, stable_id], [stable_id, approved_id],
      [approved_id, stable_id], [approved_id, approved_id]
    ]
    role_ids.each do |role_id|
      transitions.each do |old_status_id, new_status_id|
        execute <<~SQL.squish
          INSERT INTO workflows (type, tracker_id, role_id, old_status_id, new_status_id, author, assignee)
          VALUES ('WorkflowTransition', #{tracker_id}, #{role_id}, #{old_status_id}, #{new_status_id}, #{connection.quoted_false}, #{connection.quoted_false})
        SQL
      end
    end
  end
end
