# Include hook code here
require "metaid"
require "acts_as_url_param"
require "redirect"
require "url_utils"
ActiveRecord::Base.send(:include, ActsAsUrlParam)