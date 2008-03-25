module ActsAsUrlParam
  def self.included(base)
    base.extend ActMethods
  end
  
  module ActMethods
    
    def acts_as_url_param(*args, &block)
      extend ClassMethods
      include InstanceMethods
      include Caring::Utilities::UrlUtils
      extend Caring::Utilities::UrlUtils
      
      class_inheritable_accessor :acts_as_url_options, :acts_as_url_param_base
      # No extract options in rails 1.2.x
      options = args.respond_to?(:extract_options!) ? args.extract_options! : extract_options_from_args!(args)
      self.acts_as_url_options = options
      options[:column] = args.first || 'url_name'
      options[:from] ||= default_from_column
      
      if options[:redirectable]
        options[:on] ||= :update
        make_redirectable
      end
      
      options[:on] ||= :create
      options[:block] = block if block_given?
      callback = "before_validation"
      if options[:on] == :create
        callback += "_on_create"
        before_validation :set_url_param_if_non_existant
      end
      send callback, :set_url_param
      validates_presence_of(options[:from], :if => :empty_param?) unless options[:allow_blank]
      
      define_finder
      define_url_param_setter
      define_availability_check
      
      self.class_eval do
        alias_method_chain :validate, :unique_url unless method_defined? :validate_without_unique_url
      end
    end
    
    private
    
    def make_redirectable
      has_many :redirects, :as => :redirectable
      before_save :add_redirect
      
      class_def :add_redirect do
        if !new_record? && @name_changed && @old_name
          redirects.create(:url_name => @old_name)
        end
      end
      
      meta_def :find_redirect do |name|
        redirect = Redirect.find_by_class_and_name(self,name)
        redirect.redirectable if redirect
      end
    end
    
    def define_finder
      meta_def :find_by_url do |*args|
        send("find_by_#{acts_as_url_options[:column]}", *args)
      end
    end
    
    def define_url_param_setter
      class_def "#{acts_as_url_options[:column]}=" do |value|
        @url_name_manually_set = true if value
        @old_name = read_attribute(acts_as_url_options[:column]) unless @name_changed
        write_attribute(acts_as_url_options[:column], url_safe(value))
        @name_changed = true unless read_attribute(acts_as_url_options[:column]) == @old_name || !@old_name
      end
    end
    
    def define_availability_check
      klass = self
      meta_def :url_param_available_for_model? do |*args|
        candidate, id = *args
        conditions = acts_as_url_options[:conditions] + ' AND ' if acts_as_url_options[:conditions]
        conditions ||= '' 
        conditions += "#{acts_as_url_options[:column]} = ?"
        conditions += " AND id != ?" if id
        conditions = [conditions, candidate]
        conditions << id if id
        available = if descends_from_active_record? or self == klass
          count(:conditions => conditions) == 0
        else
          base_class.count(:conditions => conditions) == 0
        end
        if acts_as_url_options[:redirectable] && available
          re_conditions = "url_name = ? AND redirectable_class = ?"
          re_conditions += "AND redirectable_id != ?" if id
          re_conditions = [re_conditions, candidate, self.to_s]
          re_conditions << id if id
          available = Redirect.count(:conditions => re_conditions) == 0
        end
        available
      end
    end
    
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
        if url_param.blank? or (acts_as_url_options[:on] != :create && !@url_name_manually_set)
          send(acts_as_url_options[:before]) if acts_as_url_options[:before]
          url = compute_url_param
          send("#{acts_as_url_options[:column]}=", url) unless url.blank?
          @url_name_manually_set = false
          @url_param_validated = true
        end
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