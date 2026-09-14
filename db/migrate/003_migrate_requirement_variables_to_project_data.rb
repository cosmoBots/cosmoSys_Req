# First cosmosys_req schema transition after the released 0.1.0 baseline.
class MigrateRequirementVariablesToProjectData < ActiveRecord::Migration[6.1]
  LEGACY_COLUMNS = {
    rq_var: :string,
    rq_var_name: :string,
    rq_value: :string
  }.freeze
  RELEASED_LEGACY_COLUMNS = LEGACY_COLUMNS.slice(:rq_var, :rq_value).freeze

  def up
    ensure_base_contract!
    sources = legacy_sources
    validate_source_keys!(sources)

    Issue.transaction do
      sources.group_by(&:project_id).each_value do |project_sources|
        project = Project.find(project_sources.first.project_id)
        project.with_cosmosys_locale do
          section = find_or_create_data_section!(project, project_sources.first.author)
          project_sources.each { |source| create_datum!(source, project, section) }
        end
      end
    end

    remove_index :issues, name: 'index_issues_on_lower_rq_var' if index_exists?(:issues, name: 'index_issues_on_lower_rq_var')
    LEGACY_COLUMNS.each_key do |column|
      remove_column :issues, column if column_exists?(:issues, column)
    end
    Issue.reset_column_information
  end

  def down
    RELEASED_LEGACY_COLUMNS.each do |column, type|
      add_column :issues, column, type unless column_exists?(:issues, column)
    end
    add_index :issues, 'LOWER(rq_var)', name: 'index_issues_on_lower_rq_var', where: 'rq_var IS NOT NULL' unless index_exists?(:issues, name: 'index_issues_on_lower_rq_var')
    Issue.reset_column_information

    datum_tracker_ids = Tracker.where(csys_item_kind: 'datum').pluck(:id)
    migrated = Issue.where(tracker_id: datum_tracker_ids).where.not(csys_datum_source_issue_id: nil).to_a
    Issue.transaction do
      migrated.each do |datum|
        source = Issue.find_by(id: datum.csys_datum_source_issue_id)
        next unless source

        source.update_columns(
          rq_var: datum.csid,
          rq_value: datum.csys_value
        )
        datum.destroy!
      end
      remove_empty_generated_sections!
    end
  end

  private

  Source = Struct.new(:id, :project_id, :author_id, :csid, :key, :name, :value, keyword_init: true) do
    def author
      User.find_by(id: author_id) || User.active.order(:id).first || User.find_by(login: 'admin')
    end
  end

  def ensure_base_contract!
    missing = %i[csys_value csys_datum_source_issue_id].reject { |column| column_exists?(:issues, column) }
    raise "cosmoSys project-data migration must run first (missing #{missing.join(', ')})" if missing.any?
    raise 'cosmoSys csData tracker is missing' unless Tracker.where(csys_item_kind: 'data_section').exists?
    raise 'cosmoSys csDatum tracker is missing' unless Tracker.where(csys_item_kind: 'datum').exists?
  end

  def legacy_sources
    return [] unless column_exists?(:issues, :rq_var) && column_exists?(:issues, :rq_value)

    quoted = connection.quote_column_name('rq_var')
    name_projection = column_exists?(:issues, :rq_var_name) ? 'rq_var_name' : 'NULL AS rq_var_name'
    rows = connection.select_all(<<~SQL.squish)
      SELECT id, project_id, author_id, csid, rq_var, #{name_projection}, rq_value
      FROM issues
      WHERE #{quoted} IS NOT NULL AND TRIM(#{quoted}) <> ''
      ORDER BY id
    SQL
    rows.map do |row|
      Source.new(
        id: row.fetch('id').to_i,
        project_id: row.fetch('project_id').to_i,
        author_id: row.fetch('author_id').to_i,
        csid: row.fetch('csid'),
        key: row.fetch('rq_var').to_s.strip,
        name: row.fetch('rq_var_name').to_s.strip.presence,
        value: row.fetch('rq_value')
      )
    end
  end

  def validate_source_keys!(sources)
    invalid = sources.reject { |source| source.key.match?(/\A[A-Za-z][A-Za-z0-9_]*\z/) }
    raise "Invalid requirement variable keys: #{invalid.map(&:key).uniq.join(', ')}" if invalid.any?

    duplicates = sources.group_by { |source| [Project.find(source.project_id).root.id, source.key.downcase] }
                        .select { |_identity, matches| matches.size > 1 }
    return if duplicates.empty?

    details = duplicates.values.map { |matches| "#{matches.first.key} (issues #{matches.map(&:id).join(', ')})" }
    raise "Duplicate requirement variable keys in a project tree: #{details.join('; ')}"
  end

  def find_or_create_data_section!(project, author)
    existing = Cosmosys::ReportPlaceholder.includes(:issue).find_by(project_id: project.id, kind: 'project_data')
    return existing.issue if existing

    tracker = project.trackers.find { |candidate| candidate.csys_item_kind == 'data_section' } ||
              Tracker.where(csys_item_kind: 'data_section').order(:id).first!
    issue = Issue.new(
      project: project,
      tracker: tracker,
      status: tracker.default_status || IssueStatus.order(:position, :id).first!,
      author: author,
      subject: I18n.t(:label_cosmosys_project_data_section)
    )
    issue.csys_report_placeholder_kind = 'project_data'
    issue.notify = false
    issue.save!
    issue
  end

  def create_datum!(source, project, section)
    existing = Issue.joins(:tracker)
                    .where(project_id: project.root.self_and_descendants.select(:id))
                    .where(trackers: { csys_item_kind: 'datum' })
                    .where('LOWER(issues.csid) = ?', source.key.downcase)
                    .first
    raise "Datum #{source.key} already exists and cannot be reconciled during schema migration" if existing

    tracker = project.trackers.find { |candidate| candidate.csys_item_kind == 'datum' } ||
              Tracker.where(csys_item_kind: 'datum').order(:id).first!
    datum = Issue.new(
      project: project,
      tracker: tracker,
      status: tracker.default_status || IssueStatus.order(:position, :id).first!,
      author: source.author,
      parent: section,
      csid: source.key,
      subject: source.name || source.key,
      description: I18n.t(:text_cosmosys_datum_migrated_from_requirement, csid: source.csid),
      csys_value: source.value,
      csys_datum_source_issue_id: source.id
    )
    datum.notify = false
    datum.save!
  end

  def remove_empty_generated_sections!
    Cosmosys::ReportPlaceholder.where(kind: 'project_data').includes(:issue).find_each do |placeholder|
      issue = placeholder.issue
      issue.destroy! if issue && issue.children.empty?
    end
  end
end
