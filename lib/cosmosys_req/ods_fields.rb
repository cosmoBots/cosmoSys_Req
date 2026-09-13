require_dependency File.expand_path('../../../cosmosys/lib/cosmosys/ods_item_field_registry', __dir__)

module CosmosysReq
  module OdsFields
    SCALAR_FIELDS = %w[
      rq_type rq_level rq_srcs rq_var rq_var_name
      rq_value rq_rationale rq_verif_description
      rq_compl_state rq_compl_justif
      rq_implem_progress
    ].freeze

    module_function

    def register!
      SCALAR_FIELDS.each do |name|
        next if Cosmosys::OdsItemFieldRegistry.names.include?(name)

        Cosmosys::OdsItemFieldRegistry.register(
          name,
          writer: ->(issue, value) { issue.public_send("#{name}=", value.presence) if issue.cosmosys_requirement? }
        )
      end

      return if Cosmosys::OdsItemFieldRegistry.names.include?('rq_verif_methods')

      Cosmosys::OdsItemFieldRegistry.register(
        'rq_verif_methods',
        reader: ->(issue) { issue.cosmosys_requirement? ? issue.rq_verif_method_values.join(',') : nil },
        writer: lambda do |issue, value|
          issue.rq_verif_method_values = value.to_s.split(/[\r\n,]+/).map(&:strip).reject(&:blank?) if issue.cosmosys_requirement?
        end
      )

      return if Cosmosys::OdsItemFieldRegistry.names.include?('rq_deriv_src')

      Cosmosys::OdsItemFieldRegistry.register(
        'rq_deriv_src',
        reader: ->(issue) { issue.cosmosys_requirement? ? issue.rq_deriv_src&.csid : nil },
        deferred: true,
        remapper: ->(value, context) { context.fetch(:csid_map, {}).fetch(value.to_s, value) },
        writer: lambda do |issue, value|
          next unless issue.cosmosys_requirement?

          issue.rq_deriv_src = if value.to_s.strip.empty?
                                 nil
                               else
                                 issue.project.issues.find_by!(csid: value.to_s.strip)
                               end
        end
      )
    end
  end
end

CosmosysReq::OdsFields.register!
