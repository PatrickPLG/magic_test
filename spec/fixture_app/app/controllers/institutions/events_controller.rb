module Institutions
  class EventsController < ApplicationController
    layout "admin"
    before_action -> { require_role!(Institutions::Employee) }
    before_action :set_institution
    before_action :set_event, only: [:edit, :update, :destroy]

    def index
      @events = @institution.events.order(:id)
    end

    def new
      @event = @institution.events.build
    end

    def create
      @event = @institution.events.build(event_params)
      if @event.save
        redirect_to institution_events_path(@institution), notice: t("events.create.success")
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      if @event.update(event_params)
        redirect_to institution_events_path(@institution), notice: t("events.update.success")
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @event.destroy
      redirect_to institution_events_path(@institution), notice: "Arrangement slettet"
    end

    private

    def set_institution
      @institution = Institution.find(params[:institution_id])
    end

    def set_event
      @event = @institution.events.find(params[:id])
    end

    def event_params
      params.require(:events_event).permit(:name, :description, :terms_accepted, :account_number, :registration_number,
        :starts_at, :category_id, :location, :published,
        ticket_types_attributes: [:id, :name, :price, :_destroy])
    end
  end
end
