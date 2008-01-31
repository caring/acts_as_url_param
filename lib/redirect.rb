# redirectable_type
# redirectable_id
# redirectable_class
# name

class Redirect < ActiveRecord::Base
  belongs_to :redirectable, :polymorphic => true
  before_create :set_real_class
  
  private
  def set_real_class
    self.redirectable_class = redirectable.class.to_s
  end
end