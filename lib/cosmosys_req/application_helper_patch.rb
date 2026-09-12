module CosmosysReq
  module ApplicationHelperPatch
    def parse_redmine_links(text, default_project, obj, attr, only_path, options)
      project = default_project || obj.try(:project)
      if project && text.include?('${')
        resolver = CosmosysReq::VariableDictionary.new(project: project, user: User.current)
        text.replace(resolver.resolve(text) { |value| ERB::Util.html_escape(value) })
      end

      super
    end
  end
end
