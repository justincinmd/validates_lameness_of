require 'test/unit'
require 'test/lib/activerecord_helper'
require 'init'

class ValidatesLamenessOfTest < ActiverecordHelper

  def setup
  end
  
  def test_capitilization
    # minimum_size: 5
    # maximum_uppercase_percentage: 40
    
    valid_comment(nil)
    valid_comment("")
    valid_comment("abcd")
    valid_comment("ABCD")
    valid_comment("Testi")
    valid_comment("TEsti")
    valid_comment("A.B.C.D.") # Tests minimum size
    invalid_comment("TESti")
    invalid_comment("TESTI")
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