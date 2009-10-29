require 'test/unit'
require 'test/lib/activerecord_helper'
require 'init'

class ValidatesLamenessOfTest < ActiverecordHelper

  def setup
    Object.class_eval do
     remove_const "Comment" if const_defined? "Comment"
    end
    load "fixtures/comment.rb"
  end
  
  def test_capitilization
    Comment.validate_capitilization_of :comment, neutral_capitilization_options.merge({:minimum_size => 5, :maximum_uppercase_percentage => 40})
    
    valid_comment("abcd")
    valid_comment("ABCD")
    valid_comment("Testi")
    valid_comment("TEsti")
    valid_comment("A.B.C.D.") # Tests minimum size
    invalid_comment("TESti")
    invalid_comment("TESTI")
  end

  def test_maximum_capital_words
    Comment.validate_capitilization_of :comment, neutral_capitilization_options.merge({:maximum_capital_words => 2})

    valid_comment("TWO CAPITAL words.")
    invalid_comment("THREE CAPITAL WORDS")
  end

  def test_maximum_percentage_of_capital_words
    Comment.validate_capitilization_of :comment, neutral_capitilization_options.merge({:maximum_percentage_of_capital_words => 50})

    valid_comment("under fifty percent capital")
    valid_comment("at fifty PERCENT CAPITAL")
    invalid_comment("OVER fifty PERCENT CAPITAL")
  end

  def test_exclamation_marks
    Comment.validate_exclamation_marks_of :comment, :maximum_in_composition => 2, :maximum_together => 1, :report_lameness => true

    valid_comment("ABDCAKAKE")
    valid_comment("no marks is valid")
    valid_comment("one mark is valid!")
    invalid_comment("two marks together is not valid!!")
    valid_comment("two marks apart! is valid!")
    invalid_comment("three marks! not! valid!")
  end

  def test_valid_blank_and_nil
    valid_comment(nil)
    valid_comment("")
  end
  
  protected
  
  def valid_comment(comment)
    comment = Comment.new(:comment => comment)
    assert comment.valid?
    assert !comment.errors.lame_fields.include?(:comment)
  end
  
  def invalid_comment(comment)
    comment = Comment.new(:comment => comment)
    assert !comment.valid?
    assert comment.errors.lame_fields.include?(:comment)
  end

  def neutral_capitilization_options
    {:minimum_size => 0, 
      :maximum_uppercase_percentage => 100,
      :maximum_capital_words => 100000,
      :maximum_percentage_of_capital_words => 100,
      :report_lameness => true}
  end
  
end