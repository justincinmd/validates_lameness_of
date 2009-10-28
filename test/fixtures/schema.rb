ActiveRecord::Schema.define do
  create_table "comments", :force => true do |t|
    t.text "comment"
    t.integer "id"
  end
end