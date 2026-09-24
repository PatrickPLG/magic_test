module StudentOrganisations
  class MembershipsController < ApplicationController
    layout "admin"
    before_action -> { require_role!(Institutions::StudentOrganisation) }

    def index
      @memberships = current_role.memberships.order(:id)
    end

    def new
      @membership = current_role.memberships.build
      respond_to { |format| format.js }
    end

    def create
      @membership = current_role.memberships.build(membership_params)
      respond_to do |format|
        if @membership.save
          format.js
        else
          format.js { render :new }
        end
      end
    end

    def destroy
      current_role.memberships.find(params[:id]).destroy
      redirect_to student_organisation_student_organisation_memberships_path, notice: "Medlem fjernet"
    end

    private

    def membership_params
      params.require(:student_organisation_membership).permit(:name, :email, :membership_type)
    end
  end
end
