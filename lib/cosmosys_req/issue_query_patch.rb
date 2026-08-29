require_dependency 'issue_query'

module CosmosysReq
  module IssueQueryPatch
    class RichTextQueryColumn < QueryColumn
      def cosmosys_report_rich_text?
        true
      end
    end

    COLUMNS = {
      requirement_type: { caption: :field_requirement_type },
      requirement_level: { caption: :field_requirement_level },
      requirement_rationale: { caption: :field_requirement_rationale, rich_text: true },
      requirement_sources: { caption: :field_requirement_sources },
      requirement_variable: { caption: :field_requirement_variable },
      requirement_value: { caption: :field_requirement_value },
      requirement_verification_method_values: { caption: :field_requirement_verification_methods, sortable: false },
      requirement_verification_description: { caption: :field_requirement_verification_description, rich_text: true },
      requirement_compliance_state: { caption: :field_requirement_compliance_state },
      requirement_compliance_justification: { caption: :field_requirement_compliance_justification, rich_text: true },
      requirement_implementation_progress: { caption: :field_requirement_implementation_progress },
      requirement_derivation_source: { caption: :field_requirement_derivation_source, sortable: false }
    }.freeze

    def self.prepended(base)
      COLUMNS.each do |name, definition|
        next if base.available_columns.any? { |column| column.name == name }

        options = { caption: definition.fetch(:caption) }
        options[:sortable] = "#{Issue.table_name}.#{name}" unless definition[:sortable] == false
        column_class = definition[:rich_text] ? RichTextQueryColumn : QueryColumn
        base.available_columns << column_class.new(name, **options)
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
