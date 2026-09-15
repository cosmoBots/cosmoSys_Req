module CosmosysReq
  module TrackerCapabilities
    MANAGEMENT_FIELDS = %w[assigned_to_id start_date due_date estimated_hours done_ratio].freeze
    DEFINITIONS = {
      'requirement' => { management: false, release_tracking: false },
      'requirement_management' => { management: true, release_tracking: false },
      'requirement_release' => { management: false, release_tracking: true },
      'requirement_management_release' => { management: true, release_tracking: true }
    }.transform_values(&:freeze).freeze

    def cosmosys_req_capabilities
      DEFINITIONS.fetch(csys_key.to_s, { management: false, release_tracking: false }.freeze)
    end

    def cosmosys_req_management?
      cosmosys_req_capabilities[:management]
    end

    def cosmosys_req_release_tracking?
      cosmosys_req_capabilities[:release_tracking]
    end

    def core_fields=(fields)
      normalized = Array(fields).map(&:to_s)
      normalized -= MANAGEMENT_FIELDS if DEFINITIONS.key?(csys_key.to_s) && !cosmosys_req_management?
      super(normalized)
    end
  end
end

Tracker.prepend(CosmosysReq::TrackerCapabilities) unless Tracker < CosmosysReq::TrackerCapabilities
