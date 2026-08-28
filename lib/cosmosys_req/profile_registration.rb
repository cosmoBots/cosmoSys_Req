require_dependency File.expand_path('../../../cosmosys/lib/cosmosys/item_kind_registry', __dir__)
require_dependency File.expand_path('../../../cosmosys/lib/cosmosys/project_profile_registry', __dir__)

module CosmosysReq
  module ProfileRegistration
    REQUIREMENT_TYPE_COLORS = {
      'complex' => 'lightyellow',
      'optical' => 'lightcyan',
      'mechanical' => 'antiquewhite2',
      'hardware' => 'lavenderblush2',
      'software' => 'darkseagreen1'
    }.freeze

    module_function

    def register!
      if Cosmosys::ItemKindRegistry.registered?('requirement')
        profile = Cosmosys::ItemKindRegistry.fetch('requirement')
        raise 'item profile requirement belongs to another provider' unless profile.provider == :cosmosys_req

        return profile
      end

      Cosmosys::ItemKindRegistry.register(
        'requirement',
        label: :label_cosmosys_req_item_profile,
        description: :text_cosmosys_req_item_profile,
        provider: :cosmosys_req,
        diagram_shape: 'record',
        diagram_fill_color: ->(issue, **) { REQUIREMENT_TYPE_COLORS.fetch(issue.requirement_type.to_s, 'white') },
        diagram_border_color: 'darkgreen',
        reference_mode: 'csid',
        dependency_rankdir: 'TB',
        can_have_children: false,
        can_split: false,
        aggregate_children: false,
        allowed_parent_profiles: %w[info].freeze,
        dsm_mode: 'all'
      )
    end
  end
end

CosmosysReq::ProfileRegistration.register!

unless Cosmosys::ProjectProfileRegistry.registered?('requirements')
  Cosmosys::ProjectProfileRegistry.register(
    'requirements',
    label: :label_cosmosys_req_project_profile,
    description: :text_cosmosys_req_project_profile,
    provider: :cosmosys_req,
    required_trackers: [
      { key: 'requirement', name: 'csRq', item_profile: 'requirement' }.freeze,
      { key: 'requirement_management', name: 'csRqm', item_profile: 'requirement' }.freeze,
      { key: 'requirement_release', name: 'csRqr', item_profile: 'requirement' }.freeze,
      { key: 'requirement_management_release', name: 'csRqmr', item_profile: 'requirement' }.freeze
    ].freeze,
    default_root_tracker: 'cs_info',
    ods_export_template: 'plugins/cosmosys_req/assets/templates/ods/requirements_export_template.ods',
    default_disabled_modules: %w[calendar time_tracking news gantt files].freeze,
    default_report_columns: %w[
      tracker status requirement_type requirement_level author assigned_to
      requirement_compliance_state
    ].freeze,
    default_report_field_presentations: {
      'requirement_type' => 'metadata',
      'requirement_level' => 'metadata',
      'requirement_compliance_state' => 'metadata'
    }.freeze,
    default_item_list_columns: %w[
      chapter_label subject tracker status priority assigned_to updated_on
      requirement_type requirement_level requirement_compliance_state
    ].freeze
  )
end
