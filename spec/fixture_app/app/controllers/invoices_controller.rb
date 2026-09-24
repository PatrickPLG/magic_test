class InvoicesController < ApplicationController
  layout "bare"

  def show
    @invoice = Invoice.find(params[:id])
  end
end
