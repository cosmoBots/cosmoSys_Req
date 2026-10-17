module CosmosysReq
  class SnapshotBaselineRebuilder
    CALLBACK_KEY = :cosmosys_req_approved_presentation_baselines

    def self.register!
      Cosmosys::ProjectSnapshotMaterializationCallbacks.register(CALLBACK_KEY) do |context|
        new(context).call
      end
    end

    def initialize(context)
      @context = context
    end

    def call
      return unless context.fetch(:purpose).to_sym == :snapshot

      user = context.fetch(:user)
      Array(context.fetch(:items)).each do |issue|
        profile = issue.cosmosys_item_kind
        maturity = issue.status&.cosmosys_maturity_level.to_i
        next unless profile.approved_presentation_baseline == true
        next unless maturity > Cosmosys::ApprovedPresentationBaseline::CONSOLIDATED_MATURITY_FLOOR

        Cosmosys::ApprovedPresentationBaseline.capture!(issue, user: user)
      end
    end

    private

    attr_reader :context
  end
end

CosmosysReq::SnapshotBaselineRebuilder.register!
