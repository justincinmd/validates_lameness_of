module ValidatesLamenessOf
  # Default data directory.  This should persist across deployments
  # Defaults to "tmp/bayes_data"
  mattr_accessor :data_directory
  @@data_directory = 'tmp/lameness_data'

  # Validates whether the specified value has too many capital letters.  Returns nil if the value is valid, otherwise returns an array
  # containing one or more validation error messages.
  #
  # Configuration options:
  # * <tt>message</tt> - A custom error message (default is: " contains too many capital letters.")
  # * <tt>maximum_uppercase_percentage</tt> - Maximum percentage of uppercase letters considered not lame (default is 40)
  # * <tt>minimum_size</tt> - Minimum number of characters in string for validation to occur (default is 20)
  # * <tt>maximum_capital_words</tt> - Maximum number of capital words allowed (default is 5)
  # * <tt>maximum_percentage_of_capital_words</tt> - Maximum percentage of all words allowed to be capital (default is 100)
  def self.validate_capitilization_of(value, options={})
    default_options = { :message => ' contains too many capital letters.', :maximum_uppercase_percentage => 40,
      :minimum_size => 20, :maximum_capital_words => 5, :maximum_percentage_of_capital_words => 100}
    options.merge!(default_options) {|key, old, new| old}  # merge the default options into the specified options, retaining all specified options

    total_characters = value.count("a-zA-Z").to_f
    total_uppercase = value.count("A-Z").to_f
    
    return nil if total_characters < options[:minimum_size]

    percentage_uppercase = (total_uppercase / total_characters) * 100

    return [options[:message] ] if percentage_uppercase > options[:maximum_uppercase_percentage].to_f

    number_of_capital_words = value.scan(Regexp.new(/\b[A-Z]{2,}\b/)).size
    number_of_words = value.scan(Regexp.new(/\b\w{2,}\b/)).size
    percentage_of_capital_words = ((number_of_capital_words.to_f / number_of_words.to_f) * 100)

    return [options[:message]] if number_of_capital_words > options[:maximum_capital_words]
    return [options[:message]] if percentage_of_capital_words > options[:maximum_percentage_of_capital_words]

    return nil    # represents no validation errors
  end
  
  # Validates whether the specified value has too many exclamation marks.  Returns nil if the value is valid, otherwise returns an array
  # containing one or more validation error messages.
  #
  # Configuration options:
  # * <tt>message</tt> - A custom error message (default is: " contains too many exclamation marks.")
  # * <tt>maximum_in_composition</tt> - Maximum number of exclamation marks in the text (default is 3)
  # * <tt>maximum_together</tt> - Maximum number of exclamation marks together (default is 1)
  def self.validate_exclamation_marks_of(value, options={})
    default_options = { :message => ' contains too many exclamation marks.', :maximum_in_composition => 3,
      :maximum_together => 1}
    options.merge!(default_options) {|key, old, new| old}  # merge the default options into the specified options, retaining all specified options

    total_marks = value.count("!")

    return [options[:message]] if total_marks > options[:maximum_in_composition]

    # if more than maximum_together exclamation marks appear together, fail validation
    return [options[:message]] if !value.index(Regexp.new(Array.new(options[:maximum_together] + 1, '!').join)).nil?

    return nil
  end

  def self.report_lameness(value, class_name, field)
    ValidatesLamenessOf.report(value, "lame", class_name, field)
  end

  def self.report_unlameness(value, class_name, field)
    ValidatesLamenessOf.report(value, "unlame", class_name, field)
  end

  def self.report(value, classification, class_name, field)
    require 'classifier' if !defined?(Classifier)
    require 'madeleine' if !defined?(SnapshotMadeleine)
    
    ValidatesLamenessOf.report_bayes(value, classification, class_name, field)
  end

  def self.report_bayes(value, category, class_name, field)
    m = SnapshotMadeleine.new("#{ValidatesLamenessOf.data_directory}/#{class_name}/#{field}") {
      Classifier::Bayes.new 'lame', 'unlame'
    }
    m.system.train(category, value) unless (ValidatesLamenessOf.is_lame?(category, class_name, field) and category == 'lame') # it's being marked lame but it already is
    m.take_snapshot
  end

  def self.is_lame?(value, class_name, field)
    m = SnapshotMadeleine.new("#{ValidatesLamenessOf.data_directory}/#{class_name}/#{field}") {
      Classifier::Bayes.new 'lame', 'unlame'
    }
    classifications = m.system.classifications(value)
    if !classifications['Lame'].finite? or !classifications['Unlame'].finite?
      return false
    else
      return m.system.classify(value) == 'lame'
    end
  end
end

module ActiveRecord
  class Base
    before_validation :reset_lame_fields
    after_validation :report_lame_fields

    protected

    def reset_lame_fields
      self.errors.reset_lame_fields
      self.errors.reset_lameness_fields
    end

    def report_lame_fields
      for field in self.errors.lame_fields
        ValidatesLamenessOf.report_lameness(self.send(field), self.class.class_name, field.to_s)
      end

      for field in self.errors.unlame_fields
        ValidatesLamenessOf.report_unlameness(self.send(field), self.class.class_name, field.to_s)
      end
    end
  end

  class Errors
    def lame_fields
      @lame_fields ||= reset_lame_fields
    end

    def reset_lame_fields
      @lame_fields = []
    end

    def add_lame_field(field)
      @lame_fields << field unless lame_fields.include?(field)
    end

    def lameness_fields
      @lameness_fields ||= reset_lameness_fields
    end

    def reset_lameness_fields
      @lameness_fields = []
    end

    def add_lameness_field(field)
      @lameness_fields << field unless lameness_fields.include?(field)
    end

    def unlame_fields
      lameness_fields - lame_fields
    end
  end

  module Validations
    module ClassMethods
      # Validates the capitilization of the specified attribute
      #
      #   class User < ActiveRecord::Base
      #     validate_capitilization_of :comment, :on => :create
      #   end
      #
      # Configuration options:
      # * <tt>message</tt> - A custom error message (default is: " does not appear to be a valid e-mail address")
      # * <tt>maximum_uppercase_percentage</tt> - Maximum percentage of uppercase letters considered not lame (default is 40)
      # * <tt>minimum_size</tt> - Minimum number of characters in string for validation to occur (default is 20)
      # * <tt>maximum_capital_words</tt> - Maximum number of capital words allowed (default is 5)
      # * <tt>maximum_percentage_of_capital_words</tt> - Maximum percentage of all words allowed to be capital (default is 100)
      # * <tt>report_lameness</tt> - Controls whether a lameness report is made from this validation (default is false)
      # * <tt>on</tt> - Specifies when this validation is active (default is :save, other options :create, :update)
      # * <tt>allow_nil</tt> - Allow nil values (default is true)
      # * <tt>allow_blank</tt> - Allow blank values (default is true)
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - See <tt>:if</tt>
      def validate_capitilization_of(*attr_names)
        perform_lameness_validation("validate_capitilization_of", *attr_names)
      end

      # Validates the number and repetition of exclamation marks in the specified attribute
      #
      #   class User < ActiveRecord::Base
      #     validate_exclamation_marks_of :comment, :on => :create
      #   end
      #
      # Configuration options:
      # * <tt>message</tt> - A custom error message (default is: " contains too many exclamation marks.")
      # * <tt>maximum_in_composition</tt> - Maximum number of exclamation marks in the text (default is 3)
      # * <tt>maximum_together</tt> - Maximum number of exclamation marks together (default is 1)
      # * <tt>report_lameness</tt> - Controls whether a lameness report is made from this validation (default is false)
      # * <tt>on</tt> - Specifies when this validation is active (default is :save, other options :create, :update)
      # * <tt>allow_nil</tt> - Allow nil values (default is true)
      # * <tt>allow_blank</tt> - Allow blank values (default is true)
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - See <tt>:if</tt>
      def validate_exclamation_marks_of(*attr_names)
        perform_lameness_validation("validate_exclamation_marks_of", *attr_names)
      end
      
      protected
      
      def perform_lameness_validation(method, *attr_names)
        options = { :on => :save,
                    :allow_nil => true,
                    :allow_blank => true,
                    :report_lameness => false}
        options.update(attr_names.pop) if attr_names.last.is_a?(Hash)

        validates_each(attr_names, options) do |record, attr_name, value|
          v = value.to_s
          errors = ValidatesLamenessOf.send(method, v, options)
          if !errors.nil?
            errors.each do |error|
              record.errors.add(attr_name, error)
            end

            record.errors.add_lame_field(attr_name) if options[:report_lameness]
          end
          record.errors.add_lameness_field(attr_name) if options[:report_lameness]
        end
      end
    end
  end
end
