RedmineApp::Application.routes.draw do
  match 'issues/:issue_id/cosmosys/derive-requirement',
        to: 'cosmosys_req/requirements#derive',
        via: [:get, :post],
        as: :cosmosys_req_derive
end
