module CosmosysReq
  class RequirementsController < ApplicationController
    accept_api_auth :derive
    before_action :find_requirement
    before_action :require_editable

    def derive
      @requirement_trackers = @project.trackers.select { |tracker| tracker.cosmosys_item_kind_profile.key == 'requirement' }.sort_by(&:position)
      return unless request.post?

      tracker = @requirement_trackers.detect { |candidate| candidate.id == params[:tracker_id].to_i }
      raise ActiveRecord::RecordNotFound unless tracker

      type = params[:requirement_type].presence || @issue.requirement_type
      result = Cosmosys::RelatedItemsCreator.new(
        source: @issue,
        count: params[:count],
        operation: 'blocked',
        tracker: tracker,
        user: User.current,
        issue_attributes: {
          requirement_type: type,
          requirement_level: 'derived',
          requirement_derivation_source_id: @issue.id
        },
        subject_builder: ->(source, index) { I18n.t(:text_cosmosys_req_derived_subject, number: index + 1, subject: source.subject) }
      ).call
      flash[:notice] = l(:notice_cosmosys_req_derived, count: result.issues.length)
      redirect_to issue_path(@issue)
    rescue ArgumentError, ActiveRecord::RecordInvalid, ActiveRecord::RecordNotFound => error
      flash.now[:error] = error.message
      render :derive, status: :unprocessable_entity
    end

    private

    def find_requirement
      @issue = Issue.find(params[:issue_id])
      @project = @issue.project
      raise Unauthorized unless @issue.visible?(User.current) && @issue.cosmosys_requirement?
    rescue ActiveRecord::RecordNotFound
      render_404
    end

    def require_editable
      raise Unauthorized unless @issue.editable?(User.current)
      raise Unauthorized unless User.current.allowed_to?(:manage_issue_relations, @project)
      raise Unauthorized unless User.current.allowed_to?(:add_issues, @project)
    end
  end
end
