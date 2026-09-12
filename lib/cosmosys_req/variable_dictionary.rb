module CosmosysReq
  class VariableDictionary
    EXPRESSION_PATTERN = /\$\{([A-Za-z][A-Za-z0-9_]*)(\.value)?\}/
    Entry = Struct.new(:key, :name, :value, :issue, keyword_init: true)

    def initialize(project:, user:)
      @project = project
      @user = user
    end

    def resolve(text)
      text.to_s.gsub(EXPRESSION_PATTERN) do |expression|
        entry = entries[Regexp.last_match(1).downcase]
        next expression unless entry

        replacement = Regexp.last_match(2) ? entry.value.presence : (entry.name.presence || entry.key)
        next expression if replacement.blank?

        block_given? ? yield(replacement.to_s) : replacement.to_s
      end
    end

    def entries
      @entries ||= visible_definitions.group_by { |entry| entry.key.downcase }
                                      .filter_map { |normalized, matches| [normalized, matches.first] if matches.one? }
                                      .to_h
    end

    private

    attr_reader :project, :user

    def visible_definitions
      Issue.visible(user)
           .joins(:tracker)
           .where(project_id: project.root.self_and_descendants.select(:id))
           .where(trackers: { csys_item_kind: 'requirement' })
           .where.not(rq_var: [nil, ''])
           .order(:id)
           .map do |issue|
             Entry.new(key: issue.rq_var, name: issue.rq_var_name,
                       value: issue.rq_value, issue: issue)
           end
    end
  end
end
