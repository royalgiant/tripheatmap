class AddSlugToNeighborhoods < ActiveRecord::Migration[7.1]
  def up
    add_column :neighborhoods, :slug, :string

    # Generate slugs for all existing neighborhoods
    Neighborhood.find_each do |neighborhood|
      slug = generate_slug(neighborhood)
      neighborhood.update_column(:slug, slug)
    end

    add_index :neighborhoods, :slug, unique: true
  end

  def down
    remove_index :neighborhoods, :slug
    remove_column :neighborhoods, :slug
  end

  private

  def generate_slug(neighborhood)
    # Combine name, city, and state for uniqueness
    # parameterize handles:
    # - "Los Angeles" -> "los-angeles"
    # - "St. Louis" -> "st-louis"
    # - "Washington, D.C." -> "washington-dc"
    # - Special characters, accents, etc.
    base_slug = [
      neighborhood.name,
      neighborhood.city,
      neighborhood.state
    ].compact.join('-').parameterize

    # Ensure uniqueness by checking for conflicts
    slug = base_slug
    counter = 1
    while Neighborhood.where(slug: slug).where.not(id: neighborhood.id).exists?
      slug = "#{base_slug}-#{counter}"
      counter += 1
    end

    slug
  end
end
