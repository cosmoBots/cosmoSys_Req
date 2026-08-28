module CosmosysReq
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_issues_form_details_bottom, partial: 'hooks/cosmosys_req/requirement_fields'
    render_on :view_issues_show_details_bottom, partial: 'hooks/cosmosys_req/requirement_details'
    render_on :view_issues_show_description_bottom, partial: 'hooks/cosmosys_req/requirement_operations'
  end
end
