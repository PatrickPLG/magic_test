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

  # Flipper-gated per actor: 404 unless the flag is on for the current user.
  def beta
    return render(plain: "Ikke tilgængelig", status: :not_found) unless Flipper.enabled?(:beta_dashboard, current_user)
    render layout: "admin"
  end

  # Time-dependent: what is on in the next 7 days, relative to Time.current.
  def today
    @now = Time.current
    @events = Events::Event.where(starts_at: @now..(@now + 7.days)).order(:starts_at)
  end

  def double_render
    render layout: "double"
  end

  def js_test_page
    render layout: "admin"
  end
end
