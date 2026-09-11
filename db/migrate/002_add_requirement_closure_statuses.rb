class AddRequirementClosureStatuses < ActiveRecord::Migration[6.1]
  STATUSES = {
    'Approved' => 'successful',
    'Closed' => 'successful',
    'Rejected' => 'unsuccessful',
    'Erased' => 'unsuccessful'
  }.freeze

  def up
    return unless column_exists?(:issue_statuses, :csys_closed_outcome)

    STATUSES.each do |name, outcome|
      status = status_class.where('LOWER(name) = ?', name.downcase).first || status_class.new(name: name)
      status.is_closed = true
      status.position ||= status_class.maximum(:position).to_i + 1
      status.csys_closed_outcome = outcome
      status.save!
    end
  end

  def down
    # Shared Redmine statuses may already be in use, so rollback leaves them intact.
  end

  private

  def status_class
    @status_class ||= Class.new(ActiveRecord::Base) { self.table_name = 'issue_statuses' }.tap(&:reset_column_information)
  end
end
