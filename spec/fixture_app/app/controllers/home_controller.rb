class HomeController < ApplicationController
  layout "student"

  def index
    @messages = current_user ? current_user.user_messages.order(:id) : []
    @discounts = Discount.where(status: "active").order(:id)
  end

  def preview
    @event = Events::Event.order(:id).first
  end

  def preview_frame
    render layout: "bare"
  end

  def terms
  end

  def double_render
    render layout: "double"
  end
end
