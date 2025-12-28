class CreateOfferMessages < ActiveRecord::Migration[7.1]
  def change
    create_table :offer_messages do |t|
      t.references :offer, null: false, foreign_key: { on_delete: :cascade }
      t.references :sender, polymorphic: true, null: false
      t.text :content, null: false
      t.datetime :read_at

      t.timestamps
    end

    add_index :offer_messages, [:offer_id, :created_at]
  end
end
