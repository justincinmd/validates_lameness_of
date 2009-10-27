module ValidatesLamenessOf
  # Validates whether the specified value is a valid email address.  Returns nil if the value is valid, otherwise returns an array
  # containing one or more validation error messages.
  #
  # Configuration options:
  # * <tt>message</tt> - A custom error message (default is: " does not appear to be a valid e-mail address")
  # * <tt>check_mx</tt> - Check for MX records (default is false)
  # * <tt>mx_message</tt> - A custom error message when an MX record validation fails (default is: " is not routable.")
  # * <tt>with</tt> The regex to use for validating the format of the email address (default is ValidatesEmailFormatOf::Regex)</tt>
  def self.validate_email_format(email, options={})
      default_options = { :message => ' does not appear to be a valid e-mail address',
                          :check_mx => false,
                          :mx_message => ' is not routable.',
                          :with => ValidatesEmailFormatOf::Regex }
      options.merge!(default_options) {|key, old, new| old}  # merge the default options into the specified options, retaining all specified options

      # local part max is 64 chars, domain part max is 255 chars
      # TODO: should this decode escaped entities before counting?
      begin
        domain, local = email.reverse.split('@', 2)
      rescue
        return [ options[:message] ]
      end

      unless email =~ options[:with] and not email =~ /\.\./ and domain.length <= 255 and local.length <= 64
        return [ options[:message] ]
      end

      if options[:check_mx] and !ValidatesEmailFormatOf::validate_email_domain(email)
        return [ options[:mx_message] ]
      end

      return nil    # represents no validation errors
  end

  # Validates whether the specified value is a valid email address.  Returns nil if the value is valid, otherwise returns an array
  # containing one or more validation error messages.
  #
  # Configuration options:
  # * <tt>message</tt> - A custom error message (default is: " contains too many capital letters.")
  # * <tt>maximum_uppercase_percentage</tt> - Maximum percentage of uppercase letters considered not lame (default is 40)
  # * <tt>minimum_size</tt> - Minimum number of characters in string for validation to occur (default is 20)
  def self.validate_capitilization_of(value, options={})
    default_options = { :message => ' contains too many capital letters.', :maximum_uppercase_percentage => 40,
      :minimum_size => 20}
    options.merge!(default_options) {|key, old, new| old}  # merge the default options into the specified options, retaining all specified options

    return nil if value.size < options[:minimum_size]

    total_characters = value.count("a-zA-Z").to_f
    total_uppercase = value.count("A-Z").to_f

    percentage_uppercase = (total_uppercase / total_characters) * 100

    return [options[:message] ] if percentage_uppercase > options[:maximum_uppercase_percentage].to_f

    return nil    # represents no validation errors
  end

  def self.report_lameness(value)
    if defined?(Classifier) && defined?(SnapshotMadeleine)
      ValidatesLamenessOf.report(value, "lame")
    end
  end

  def self.report_unlameness(value)
    ValidatesLamenessOf.report(value, "unlame")
  end

  def self.report(value, classification)
    if defined?(Classifier) && defined?(SnapshotMadeleine)
      ValidatesLamenessOf.report_bayes(value, classification)
      ValidatesLamenessOf.report_lsi(value, classification)
    end
  end

  def self.report_bayes(value, category)
    m = SnapshotMadeleine.new("bayes_data") {
      Classifier::Bayes.new 'lame', 'unlame'
    }
    m.system.train(category, value)
    m.take_snapshot
  end

  def self.report_lsi(value, category)
    m = SnapshotMadeleine.new("bayes_data") {
      Classifier::LSI.new
    }
    m.add_item(value, category)
    m.take_snapshot
  end

  def self.is_lame?(value)
    m = SnapshotMadeleine.new("bayes_data") {
      Classifier::Bayes.new 'lame', 'unlame'
    }
    classification = m.classify(value)

    # reinforce lameness
    ValidatesLamenessOf.report(value, classification)

    return classification == 'lame'
  end
end

module ActiveRecord
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
      # * <tt>on</tt> - Specifies when this validation is active (default is :save, other options :create, :update)
      # * <tt>allow_nil</tt> - Allow nil values (default is true)
      # * <tt>allow_blank</tt> - Allow blank values (default is true)
      # * <tt>if</tt> - Specifies a method, proc or string to call to determine if the validation should
      # * <tt>maximum_uppercase_percentage</tt> - Maximum percentage of uppercase letters considered not lame (default is 40)
      # * <tt>report_lameness</tt> - Controls whether a lameness report is made from this validation (default is true)
      # * <tt>minimum_size</tt> - Minimum number of characters in string for validation to occur (default is 20)
      #   occur (e.g. :if => :allow_validation, or :if => Proc.new { |user| user.signup_step > 2 }).  The
      #   method, proc or string should return or evaluate to a true or false value.
      # * <tt>unless</tt> - See <tt>:if</tt>
      def validate_capitilization_of(*attr_names)
        perform_lameness_validation("validate_capitilization_of", *attr_names)
      end
      
      private
      
      def perform_lameness_validation(method, *attr_names)
        options = { :on => :save,
                    :allow_nil => true,
                    :allow_blank => true,
                    :report_lameness => true}
        options.update(attr_names.pop) if attr_names.last.is_a?(Hash)

        validates_each(attr_names, options) do |record, attr_name, value|
          v = value.to_s
          errors = ValidatesLamenessOf.send(method, v, options)
          if !errors.nil?
            errors.each do |error|
              record.errors.add(attr_name, error)
            end

            record.lameness_reported = true if options[:report_lameness]
          else
            record.lameness_reported = false || record.lame if options [:report_lameness]
          end
        end
      end
    end
  end
end
