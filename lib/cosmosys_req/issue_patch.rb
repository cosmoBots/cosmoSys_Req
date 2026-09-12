require 'json'

module CosmosysReq
  module IssuePatch
    TYPES = %w[complex optical mechanical hardware software].freeze
    LEVELS = %w[external shared system derived].freeze
    VERIFICATION_METHODS = %w[to_be_defined design analysis test inspection].freeze
    COMPLIANCE_STATES = %w[to_be_confirmed not_compliant partially_compliant compliant not_applicable].freeze
    IMPLEMENTATION_PROGRESS = %w[included validated].freeze
    SAFE_ATTRIBUTES = %w[
      rq_type rq_level rq_rationale rq_srcs
      rq_var rq_var_name rq_value rq_verif_method_values
      rq_verif_description rq_compl_state
      rq_compl_justif rq_implem_progress
    ].freeze

    def self.included(base)
      base.class_eval do
        safe_attributes(*SAFE_ATTRIBUTES)
        belongs_to :rq_deriv_src, class_name: 'Issue', optional: true
        has_many :derived_requirements,
                 class_name: 'Issue',
                 foreign_key: :rq_deriv_src_id,
                 dependent: :nullify
        before_validation :cosmosys_req_apply_defaults, on: :create
        before_validation :cosmosys_req_normalize_variable
        validate :cosmosys_req_validate_fields
        validate :cosmosys_req_validate_variable_uniqueness
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

    def rq_verif_method_values
      JSON.parse(self[:rq_verif_methods].presence || '[]')
    rescue JSON::ParserError
      self[:rq_verif_methods].to_s.split(',').map(&:strip).reject(&:blank?)
    end

    def rq_verif_method_values=(values)
      normalized = Array(values).map(&:to_s).reject(&:blank?).uniq
      self[:rq_verif_methods] = normalized.to_json
    end

    private

    def cosmosys_req_apply_defaults
      return unless cosmosys_requirement?

      self.rq_type ||= 'complex'
      self.rq_level ||= 'system'
      self.rq_compl_state ||= 'to_be_confirmed'
      self.rq_verif_method_values = ['to_be_defined'] if rq_verif_method_values.empty?
    end

    def cosmosys_req_validate_fields
      return unless cosmosys_requirement?

      validates_rq_value(:rq_type, TYPES, required: true)
      validates_rq_value(:rq_level, LEVELS, required: true)
      validates_rq_value(:rq_compl_state, COMPLIANCE_STATES)
      invalid_methods = rq_verif_method_values - VERIFICATION_METHODS
      errors.add(:rq_verif_methods, :inclusion) if invalid_methods.any?
      if rq_implem_progress.present? && !IMPLEMENTATION_PROGRESS.include?(rq_implem_progress)
        errors.add(:rq_implem_progress, :inclusion)
      end
      errors.add(:rq_var, :invalid) if rq_var.present? && !rq_var.match?(/\A[A-Za-z][A-Za-z0-9_]*\z/)
    end

    def cosmosys_req_normalize_variable
      self.rq_var = rq_var.to_s.strip.presence if cosmosys_requirement?
    end

    def cosmosys_req_validate_variable_uniqueness
      return unless cosmosys_requirement? && rq_var.present? && project&.persisted?

      scope = Issue.joins(:tracker)
                   .where(project_id: project.root.self_and_descendants.select(:id))
                   .where(trackers: { csys_item_kind: 'requirement' })
                   .where('LOWER(issues.rq_var) = ?', rq_var.downcase)
      scope = scope.where.not(id: id) if persisted?
      errors.add(:rq_var, I18n.t(:error_rq_var_taken_in_project_tree)) if scope.exists?
    end

    def validates_rq_value(attribute, values, required: false)
      value = public_send(attribute)
      errors.add(attribute, :blank) if required && value.blank?
      errors.add(attribute, :inclusion) if value.present? && !values.include?(value)
    end

    def cosmosys_req_validate_derivation_source
      return if rq_deriv_src.nil?

      errors.add(:rq_deriv_src, :invalid) unless cosmosys_requirement? && rq_deriv_src.cosmosys_requirement?
      errors.add(:rq_deriv_src, :invalid) unless rq_deriv_src.project_id == project_id
    end
  end
end

Issue.include(CosmosysReq::IssuePatch) unless Issue < CosmosysReq::IssuePatch
Cosmosys::ProjectCopyReferenceRegistry.register(:rq_deriv_src_id)
