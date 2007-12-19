# Include hook code here
require "acts_as_url_param"
require "url_utils"
ActiveRecord::Base.send(:include, ActsAsUrlParam)