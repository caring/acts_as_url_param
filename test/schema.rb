ActiveRecord::Schema.define(:version => 1) do
  create_table :authors do |t|
    t.column :label, :string
    t.column :url_name, :string
  end
  
  create_table :blog_posts do |t|
    t.column :title, :string
    t.column :url_name, :string
  end
  
  create_table :items do |t|
    t.column :name, :string
    t.column :type, :string, :default => 'Item', :null => false
    t.column :url_name, :string
  end
  
  create_table :stories do |t|
    t.column :title, :string
    t.column :story_url, :string
  end
  
  create_table :users do |t|
    t.column :name, :string
    t.column :login, :string
    t.column :url_name, :string
  end
end
