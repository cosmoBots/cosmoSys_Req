require_dependency 'issue_query'

module CosmosysReq
  module IssueQueryPatch
    class RichTextQueryColumn < QueryColumn
      def cosmosys_report_rich_text?
        true
      end
    end

    COLUMNS = {
      rq_type: { caption: :field_rq_type },
      rq_level: { caption: :field_rq_level },
      rq_rationale: { caption: :field_rq_rationale, rich_text: true, inline: false },
      rq_srcs: { caption: :field_rq_srcs },
      rq_verif_method_values: { caption: :field_rq_verif_methods, sortable: false },
      rq_verif_description: { caption: :field_rq_verif_description, rich_text: true },
      rq_compl_state: { caption: :field_rq_compl_state },
      rq_compl_justif: { caption: :field_rq_compl_justif, rich_text: true },
      rq_implem_progress: { caption: :field_rq_implem_progress },
      rq_deriv_src: { caption: :field_rq_deriv_src, sortable: false }
    }.freeze

    def self.prepended(base)
      COLUMNS.each do |name, definition|
        next if base.available_columns.any? { |column| column.name == name }

        options = { caption: definition.fetch(:caption) }
        options[:sortable] = "#{Issue.table_name}.#{name}" unless definition[:sortable] == false
        options[:inline] = definition[:inline] if definition.key?(:inline)
        column_class = definition[:rich_text] ? RichTextQueryColumn : QueryColumn
        base.available_columns << column_class.new(name, **options)
      end
    end

    def initialize_available_filters
      super
      add_available_filter('rq_type', type: :list, name: :field_rq_type,
                           values: CosmosysReq::IssuePatch::TYPES.map { |value| [I18n.t("label_cosmosys_req_type_#{value}"), value] })
      add_available_filter('rq_level', type: :list, name: :field_rq_level,
                           values: CosmosysReq::IssuePatch::LEVELS.map { |value| [I18n.t("label_cosmosys_req_level_#{value}"), value] })
      add_available_filter('rq_compl_state', type: :list, name: :field_rq_compl_state,
                           values: CosmosysReq::IssuePatch::COMPLIANCE_STATES.map { |value| [I18n.t("label_cosmosys_req_compliance_#{value}"), value] })
      add_available_filter('rq_implem_progress', type: :list, name: :field_rq_implem_progress,
                           values: CosmosysReq::IssuePatch::IMPLEMENTATION_PROGRESS.map { |value| [I18n.t("label_cosmosys_req_progress_#{value}"), value] })
    end
  end
end

IssueQuery.prepend(CosmosysReq::IssueQueryPatch) unless IssueQuery < CosmosysReq::IssueQueryPatch
