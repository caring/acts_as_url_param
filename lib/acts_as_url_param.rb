module ActsAsUrlParam
  def self.included(base)
    base.extend ActMethods
  end
  
  module ActMethods
    
    def acts_as_url_param(*args, &block)
      class_inheritable_accessor :acts_as_url_options, :acts_as_url_param_base
      # No extract options in rails 1.2.x
      options = args.respond_to?(:extract_options!) ? args.extract_options! : extract_options_from_args!(args)
      self.acts_as_url_options = options
      options[:column] = args.first || 'url_name'
      options[:from] ||= default_from_column
      
      # This won't work, as the from could be a method, and it would have to be defined before acts_as_url_param
      # raise ArgumentError, "No columns found to use for setting the url_param" unless column_or_method_exists? options[:from]
      options[:on] ||= :create
      options[:block] = block if block_given?
      callback = "before_validation"
      if options[:on] == :create
        callback += "_on_create"
        before_validation :set_url_param_if_non_existant
      end
      send callback, :set_url_param
      extend ClassMethods
      include InstanceMethods
      include Caring::Utilities::UrlUtils
      extend Caring::Utilities::UrlUtils
      validates_presence_of(options[:from], :if => :empty_param?) unless options[:allow_blank]
      self.acts_as_url_options = options
      self.class_eval do
        define_method("#{options[:column]}=") do |value|
          write_attribute(options[:column], url_safe(value))
        end
        
        alias_method_chain :validate, :unique_url unless method_defined? :validate_without_unique_url
      end
      klass = self
      (class << self; self; end).module_eval do
        define_method(:url_param_available_for_model?) do |*args|
          candidate, id = *args
          conditions = acts_as_url_options[:conditions] + ' AND ' if acts_as_url_options[:conditions]
          conditions ||= '' 
          conditions += "#{acts_as_url_options[:column]} = ?"
          conditions += " AND id != ?" if id
          conditions = [conditions, candidate]
          conditions << id if id
          if descends_from_active_record? or self == klass
            count(:conditions => conditions) == 0
          else
            base_class.count(:conditions => conditions) == 0
          end
        end
      end
    end
    
    private
    def default_from_column
      %W(name label title).detect do |column_name|
        column_or_method_exists?(column_name) and self.acts_as_url_options[:to].to_s != column_name
      end
    end
    
    def column_or_method_exists?(name)
      column_names.include? name.to_s or method_defined? name
    end
    
    module ClassMethods
      def url_param_available?(candidate, id=nil)
        if proc = acts_as_url_options[:block]
          !(proc.arity == 1 ? proc.call(candidate) : proc.call(candidate, id))
        else
          url_param_available_for_model?(candidate, id)
        end
      end
      
      def compute_url_param(candidate, id=nil)
        return if candidate.blank?
        # raise ArgumentError, "The url canidate cannot be empty" if candidate.blank?
        uniquify_proc = acts_as_url_options[:block] || Proc.new { |candidate| url_param_available? candidate, id }
        uniquify(url_safe(candidate), &uniquify_proc)
      end
    end
    
    module InstanceMethods
      def compute_url_param
        # raise ArgumentError, "The column used for generating the url_param is empty" unless url_from
        self.class.compute_url_param(url_from, id)
      end
      
      def url_from
        self.class.method_defined?(acts_as_url_options[:from]) ? send(acts_as_url_options[:from]) : read_attribute(acts_as_url_options[:from])
      end
      
      def to_param
        url_param || id.to_s
      end
      
      def url_param
        read_attribute(acts_as_url_options[:column])
      end
      
      def empty_param?
        !url_param
      end
      
      private
      
      def set_url_param_if_non_existant
        unless new_record?
          set_url_param if url_param.blank?
        end
      end
      
      def set_url_param
        if url_param.blank? or acts_as_url_options[:on] != :create
          write_attribute(acts_as_url_options[:column], compute_url_param)
        end
        @url_param_validated = true
      end
      
      def validate_with_unique_url
        return true if @url_param_validated
        avail_id = new_record? ? nil : id
        unless self.class.url_param_available? to_param, avail_id
          errors.add_to_base "The url is not unique"
        end
        validate_without_unique_url
      end
    end
  end
end