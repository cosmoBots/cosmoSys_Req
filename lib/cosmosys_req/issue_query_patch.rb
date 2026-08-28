require_dependency 'issue_query'

module CosmosysReq
  module IssueQueryPatch
    COLUMNS = {
      requirement_type: :field_requirement_type,
      requirement_level: :field_requirement_level,
      requirement_sources: :field_requirement_sources,
      requirement_variable: :field_requirement_variable,
      requirement_value: :field_requirement_value,
      requirement_compliance_state: :field_requirement_compliance_state,
      requirement_implementation_progress: :field_requirement_implementation_progress,
      requirement_derivation_source: :field_requirement_derivation_source
    }.freeze

    def self.prepended(base)
      COLUMNS.each do |name, caption|
        next if base.available_columns.any? { |column| column.name == name }

        options = { caption: caption }
        options[:sortable] = "#{Issue.table_name}.#{name}" unless name == :requirement_derivation_source
        base.available_columns << QueryColumn.new(name, **options)
      end
    end

    def initialize_available_filters
      super
      add_available_filter('requirement_type', type: :list, name: :field_requirement_type,
                           values: CosmosysReq::IssuePatch::TYPES.map { |value| [I18n.t("label_cosmosys_req_type_#{value}"), value] })
      add_available_filter('requirement_level', type: :list, name: :field_requirement_level,
                           values: CosmosysReq::IssuePatch::LEVELS.map { |value| [I18n.t("label_cosmosys_req_level_#{value}"), value] })
      add_available_filter('requirement_compliance_state', type: :list, name: :field_requirement_compliance_state,
                           values: CosmosysReq::IssuePatch::COMPLIANCE_STATES.map { |value| [I18n.t("label_cosmosys_req_compliance_#{value}"), value] })
      add_available_filter('requirement_implementation_progress', type: :list, name: :field_requirement_implementation_progress,
                           values: CosmosysReq::IssuePatch::IMPLEMENTATION_PROGRESS.map { |value| [I18n.t("label_cosmosys_req_progress_#{value}"), value] })
    end
  end
end

IssueQuery.prepend(CosmosysReq::IssueQueryPatch) unless IssueQuery < CosmosysReq::IssueQueryPatch
