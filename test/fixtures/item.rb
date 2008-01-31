class ActsAsUrlParam::Item < ActsAsUrlParamBase
  acts_as_url_param :conditions => "items.type != 'Newspaper'", :redirectable => true
end