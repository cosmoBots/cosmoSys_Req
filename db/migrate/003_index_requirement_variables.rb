class IndexRequirementVariables < ActiveRecord::Migration[6.1]
  INDEX_NAME = 'index_issues_on_lower_rq_var'.freeze

  def up
    add_column :issues, :rq_var_name, :string unless column_exists?(:issues, :rq_var_name)
    return if index_exists?(:issues, 'LOWER(rq_var)', name: INDEX_NAME)

    add_index :issues, 'LOWER(rq_var)', name: INDEX_NAME,
              where: 'rq_var IS NOT NULL'
  end

  def down
    remove_index :issues, name: INDEX_NAME if index_exists?(:issues, name: INDEX_NAME)
    remove_column :issues, :rq_var_name if column_exists?(:issues, :rq_var_name)
  end
end
