class CreateEmailPreferences < ActiveRecord::Migration[7.1]
  def change
    create_table :email_preferences do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.boolean :receive_any_emails, default: true, null: false
      t.integer :new_lead_email_frequency, default: 1, null: false
      t.integer :new_offer_email_frequency, default: 1, null: false
      t.boolean :receive_message_emails, default: true, null: false
      t.boolean :receive_offer_expiring_soon_emails, default: true, null: false

      t.timestamps
    end
  end
end
