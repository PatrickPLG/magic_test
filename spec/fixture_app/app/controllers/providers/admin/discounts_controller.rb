module Providers
  module Admin
    class DiscountsController < ApplicationController
      layout "admin"
      before_action -> { require_role!(Provider) }
      before_action :set_provider
      before_action :set_discount, only: [:edit, :update, :destroy, :send_reminder, :archive, :confirm_archive]

      def index
        @discounts = @provider.discounts.where(archived: false).order(:id)
        @invoice = @provider.invoices.order(:id).first
      end

      def show
        @discount = @provider.discounts.find(params[:id])
        respond_to do |format|
          format.html
          format.js
        end
      end

      def new
        @discount = @provider.discounts.build
      end

      def create
        @discount = @provider.discounts.build(discount_params)
        if @discount.save
          redirect_to provider_admin_discounts_path(@provider), notice: t("discounts.create.success")
        else
          render :new, status: :unprocessable_entity
        end
      end

      def edit
      end

      def update
        if @discount.update(discount_params)
          redirect_to provider_admin_discounts_path(@provider), notice: t("discounts.update.success")
        else
          render :edit, status: :unprocessable_entity
        end
      end

      def destroy
        @discount.destroy
        redirect_to provider_admin_discounts_path(@provider), notice: t("discounts.destroy.success")
      end

      def send_reminder
        @discount.increment!(:reminders_sent)
        respond_to { |format| format.js }
      end

      def archive
        respond_to { |format| format.js }
      end

      def confirm_archive
        @discount.update!(archived: true)
        redirect_to provider_admin_discounts_path(@provider), notice: t("discounts.confirm_archive.success")
      end

      private

      def set_provider
        @provider = Provider.find(params[:provider_id])
      end

      def set_discount
        @discount = @provider.discounts.find(params[:id])
      end

      def discount_params
        permitted = params.require(:discount).permit(:name_da, :name_en, :description, :status, :cover_image, category_ids: [])
        if permitted[:cover_image].respond_to?(:original_filename)
          permitted[:cover_image] = permitted[:cover_image].original_filename
        end
        permitted
      end
    end
  end
end
