class EventsController < ApplicationController
  layout "student"

  def show
    @event = Events::Event.find(params[:id])
  end
end
