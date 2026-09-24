module Backoffice
  class LeadsController < ApplicationController
    layout "admin"
    before_action :authenticate_user!

    def index
      @leads = Lead.order(:id).page(params[:page])
    end

    def edit
      @lead = Lead.find(params[:id])
    end

    def update
      @lead = Lead.find(params[:id])
      if @lead.update(params.require(:lead).permit(:name, :email, :status, :note))
        redirect_to backoffice_leads_path, notice: t("leads.update.success")
      else
        render :edit, status: :unprocessable_entity
      end
    end
  end
end
