class AddHasLifetimeAccessToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :has_lifetime_access, :boolean, default: false, null: false
  end
end
