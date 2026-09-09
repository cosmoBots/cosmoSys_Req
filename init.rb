require 'redmine'

Redmine::Plugin.register :cosmosys_req do
  name 'cosmoSys Requirements'
  author 'cosmoBots.eu'
  description 'Requirements domain extension for cosmoSys.'
  version '0.1.1-dev'
  url 'https://github.com/cosmoBots/cosmoSys_Req'
  author_url 'https://cosmobots.eu'

  requires_redmine_plugin :cosmosys, version_or_higher: '0.1.0'
end

require_dependency 'issue'
require_dependency 'tracker'
require_dependency File.expand_path('lib/cosmosys_req/profile_registration', __dir__)
require_dependency File.expand_path('lib/cosmosys_req/tracker_capabilities', __dir__)
require_dependency File.expand_path('lib/cosmosys_req/issue_patch', __dir__)
require_dependency File.expand_path('lib/cosmosys_req/ods_fields', __dir__)
require_dependency File.expand_path('lib/cosmosys_req/issue_query_patch', __dir__)
require_dependency File.expand_path('lib/cosmosys_req/hooks', __dir__)
