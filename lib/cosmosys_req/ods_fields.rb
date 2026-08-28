require_dependency File.expand_path('../../../cosmosys/lib/cosmosys/ods_item_field_registry', __dir__)

module CosmosysReq
  module OdsFields
    SCALAR_FIELDS = %w[
      requirement_type requirement_level requirement_sources requirement_variable
      requirement_value requirement_rationale requirement_verification_description
      requirement_compliance_state requirement_compliance_justification
      requirement_implementation_progress
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

      return if Cosmosys::OdsItemFieldRegistry.names.include?('requirement_verification_methods')

      Cosmosys::OdsItemFieldRegistry.register(
        'requirement_verification_methods',
        reader: ->(issue) { issue.cosmosys_requirement? ? issue.requirement_verification_method_values.join(',') : nil },
        writer: lambda do |issue, value|
          issue.requirement_verification_method_values = value.to_s.split(/[\r\n,]+/).map(&:strip).reject(&:blank?) if issue.cosmosys_requirement?
        end
      )
    end
  end
end

CosmosysReq::OdsFields.register!
