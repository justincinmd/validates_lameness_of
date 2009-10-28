class Comment < ActiveRecord::Base
  validate_capitilization_of :comment, :minimum_size => 5, :maximum_uppercase_percentage => 40, :report_lameness => true
end