module Backoffice
  class DashboardController < ApplicationController
    layout "admin"
    before_action -> { require_role!(Admin, TeamMember) }

    def index
      @leads_count = Lead.count
    end
  end
end
