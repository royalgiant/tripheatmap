class CreateSubscriptions < ActiveRecord::Migration[7.1]
  def change
    create_table :subscriptions do |t|
      t.string :plan_id
      t.string :customer_id
      t.string :subscription_id
      t.references :user, null: false, foreign_key: true
      t.string :status
      t.string :interval
      t.datetime :current_period_end
      t.datetime :current_period_start

      t.timestamps
    end
  end
end
