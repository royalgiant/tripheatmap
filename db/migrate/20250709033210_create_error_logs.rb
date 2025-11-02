class CreateErrorLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :error_logs do |t|
      t.string :context, null: false
      t.text :error_message, null: false
      t.string :error_code
      t.json :metadata
      t.timestamps
    end

    add_index :error_logs, :context
    add_index :error_logs, :created_at
  end
end