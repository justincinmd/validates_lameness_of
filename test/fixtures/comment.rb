class Comment < ActiveRecord::Base
  validate_capitilization_of :comment, :minimum_size => 5, :maximum_uppercase_percentage => 40, :report_lameness => true
  validate_exclamation_marks_of :comment, :maximum_in_composition => 2, :maximum_together => 1, :report_lameness => true
end