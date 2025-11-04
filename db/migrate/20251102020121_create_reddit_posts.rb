class CreateRedditPosts < ActiveRecord::Migration[7.1]
  def change
    create_table :reddit_posts do |t|
      t.string :post_id
      t.string :subreddit
      t.string :title
      t.text :selftext
      t.string :url
      t.datetime :created_utc
      t.string :context
      t.string :city
      t.string :neighborhood
      t.string :state
      t.string :country
      t.float :lat
      t.float :lon
      t.float :confidence
      t.string :risk_level
      t.float :risk_score
      t.string :incident_type
      t.text :summary
      t.string :status, default: "pending"
      t.timestamps
    end
    add_index :reddit_posts, :post_id, unique: true
  end
end
