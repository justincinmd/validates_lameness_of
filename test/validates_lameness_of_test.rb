require 'test/unit'
require 'test/lib/activerecord_helper'
require 'init'

class ValidatesLamenessOfTest < ActiverecordHelper

  def setup
  end
  
  def test_capitilization
    # minimum_size: 5
    # maximum_uppercase_percentage: 40  
    
    valid_comment("abcd")
    valid_comment("ABCD")
    valid_comment("Testi")
    valid_comment("TEsti")
    valid_comment("A.B.C.D.") # Tests minimum size
    invalid_comment("TESti")
    invalid_comment("TESTI")
  end

  def test_exclamation_marks
    # :maximum_in_composition => 2
    # :maximum_together => 1

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
  
end