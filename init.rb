require 'redmine'

Redmine::Plugin.register :cosmosys_req do
  name 'cosmoSys Requirements'
  author 'cosmoBots.eu'
  description 'Requirements domain extension for cosmoSys.'
  version '0.3.0'
  url 'https://github.com/cosmoBots/cosmoSys_Req'
  author_url 'https://cosmobots.eu'

  requires_redmine_plugin :cosmosys, version_or_higher: '0.1.1'
end

require_dependency 'issue'
require_dependency 'tracker'
require_dependency File.expand_path('lib/cosmosys_req/profile_registration', __dir__)
require_dependency File.expand_path('lib/cosmosys_req/tracker_capabilities', __dir__)
require_dependency File.expand_path('lib/cosmosys_req/issue_patch', __dir__)
require_dependency File.expand_path('lib/cosmosys_req/ods_fields', __dir__)
require_dependency File.expand_path('lib/cosmosys_req/issue_query_patch', __dir__)
require_dependency File.expand_path('lib/cosmosys_req/hooks', __dir__)

# Render cosmoSys req view hooks before the host cosmoSys hooks on the shared
# `view_issues_show_*` / `view_issues_form_*` hooks. cosmoSys req depends on the
# host plugin, so by default it registers its listeners afterwards and its
# partials would appear after the cosmoSys diagrams. Moving the req listeners
# ahead places the requirement definition right after the issue description and
# before the cosmoSys diagram panels.
listener_classes = Redmine::Hook.send(:class_variable_get, :@@listener_classes)
if (req_index = listener_classes.index(CosmosysReq::Hooks)) &&
   (host_index = listener_classes.index(Cosmosys::Hooks)) &&
   req_index > host_index
  req_klass = listener_classes.delete_at(req_index)
  listener_classes.insert(host_index, req_klass)
  Redmine::Hook.send(:clear_listeners_instances)
end
