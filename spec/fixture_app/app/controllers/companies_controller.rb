class CompaniesController < ApplicationController
  layout "admin"
  before_action -> { require_role!(Company) }

  def dashboard
    @company = current_role
  end
end
