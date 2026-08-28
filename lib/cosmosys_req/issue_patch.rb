require 'json'

module CosmosysReq
  module IssueJournalPatch
    # journal_details.prop_key is limited to 30 characters by Redmine. These
    # aliases are an internal journal protocol; the public/native Issue fields
    # remain descriptive.
    JOURNAL_KEYS = {
      'requirement_verification_methods' => 'rq_verification_methods',
      'requirement_verification_description' => 'rq_verification_description',
      'requirement_compliance_justification' => 'rq_compliance_justification',
      'requirement_implementation_progress' => 'rq_implementation_progress',
      'requirement_derivation_source_id' => 'rq_derivation_source_id'
    }.freeze

    JOURNAL_KEYS.each do |attribute, journal_key|
      define_method(journal_key) { public_send(attribute) }
    end

    def journalized_attribute_names
      names = super
      names - JOURNAL_KEYS.keys + JOURNAL_KEYS.values
    end
  end

  module IssuePatch
    TYPES = %w[complex optical mechanical hardware software].freeze
    LEVELS = %w[external shared system derived].freeze
    VERIFICATION_METHODS = %w[to_be_defined design analysis test inspection].freeze
    COMPLIANCE_STATES = %w[to_be_confirmed not_compliant partially_compliant compliant not_applicable].freeze
    IMPLEMENTATION_PROGRESS = %w[included validated].freeze
    SAFE_ATTRIBUTES = %w[
      requirement_type requirement_level requirement_rationale requirement_sources
      requirement_variable requirement_value requirement_verification_method_values
      requirement_verification_description requirement_compliance_state
      requirement_compliance_justification requirement_implementation_progress
    ].freeze

    def self.included(base)
      base.class_eval do
        safe_attributes(*SAFE_ATTRIBUTES)
        belongs_to :requirement_derivation_source, class_name: 'Issue', optional: true
        has_many :derived_requirements,
                 class_name: 'Issue',
                 foreign_key: :requirement_derivation_source_id,
                 dependent: :nullify
        before_validation :cosmosys_req_apply_defaults, on: :create
        validate :cosmosys_req_validate_fields
        validate :cosmosys_req_validate_derivation_source
      end
    end

    def cosmosys_requirement?
      cosmosys_item_kind_key == 'requirement'
    end

    def cosmosys_req_management?
      cosmosys_requirement? && tracker&.cosmosys_req_management?
    end

    def cosmosys_req_release_tracking?
      cosmosys_requirement? && tracker&.cosmosys_req_release_tracking?
    end

    def requirement_verification_method_values
      JSON.parse(self[:requirement_verification_methods].presence || '[]')
    rescue JSON::ParserError
      self[:requirement_verification_methods].to_s.split(',').map(&:strip).reject(&:blank?)
    end

    def requirement_verification_method_values=(values)
      normalized = Array(values).map(&:to_s).reject(&:blank?).uniq
      self[:requirement_verification_methods] = normalized.to_json
    end

    private

    def cosmosys_req_apply_defaults
      return unless cosmosys_requirement?

      self.requirement_type ||= 'complex'
      self.requirement_level ||= 'system'
      self.requirement_compliance_state ||= 'to_be_confirmed'
      self.requirement_verification_method_values = ['to_be_defined'] if requirement_verification_method_values.empty?
    end

    def cosmosys_req_validate_fields
      return unless cosmosys_requirement?

      validates_requirement_value(:requirement_type, TYPES, required: true)
      validates_requirement_value(:requirement_level, LEVELS, required: true)
      validates_requirement_value(:requirement_compliance_state, COMPLIANCE_STATES)
      invalid_methods = requirement_verification_method_values - VERIFICATION_METHODS
      errors.add(:requirement_verification_methods, :inclusion) if invalid_methods.any?
      if requirement_implementation_progress.present? && !IMPLEMENTATION_PROGRESS.include?(requirement_implementation_progress)
        errors.add(:requirement_implementation_progress, :inclusion)
      end
    end

    def validates_requirement_value(attribute, values, required: false)
      value = public_send(attribute)
      errors.add(attribute, :blank) if required && value.blank?
      errors.add(attribute, :inclusion) if value.present? && !values.include?(value)
    end

    def cosmosys_req_validate_derivation_source
      return if requirement_derivation_source.nil?

      errors.add(:requirement_derivation_source, :invalid) unless cosmosys_requirement? && requirement_derivation_source.cosmosys_requirement?
      errors.add(:requirement_derivation_source, :invalid) unless requirement_derivation_source.project_id == project_id
    end
  end
end

Issue.include(CosmosysReq::IssuePatch) unless Issue < CosmosysReq::IssuePatch
Issue.prepend(CosmosysReq::IssueJournalPatch) unless Issue < CosmosysReq::IssueJournalPatch
