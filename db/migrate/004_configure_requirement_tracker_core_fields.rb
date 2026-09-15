class ConfigureRequirementTrackerCoreFields < ActiveRecord::Migration[6.1]
  MANAGEMENT_FIELDS = %w[
    assigned_to_id start_date due_date estimated_hours done_ratio
  ].freeze

  TRACKER_CAPABILITIES = {
    'requirement' => false,
    'requirement_management' => true,
    'requirement_release' => false,
    'requirement_management_release' => true
  }.freeze

  def up
    TRACKER_CAPABILITIES.each do |key, management|
      tracker = Tracker.find_by(csys_key: key)
      next unless tracker

      enabled = Tracker::CORE_FIELDS.dup
      enabled -= MANAGEMENT_FIELDS unless management
      tracker.core_fields = enabled
      tracker.save!
    end
  end

  def down
    TRACKER_CAPABILITIES.each_key do |key|
      tracker = Tracker.find_by(csys_key: key)
      next unless tracker

      tracker.update_column(:fields_bits, 0)
    end
  end
end
