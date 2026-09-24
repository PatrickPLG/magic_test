module Institutions
  class StudentsController < ApplicationController
    layout "admin"
    before_action -> { require_role!(Institutions::Employee) }

    def index
      @institution = Institution.find(params[:institution_id])
      @students = Student.order(:id)
    end
  end
end
