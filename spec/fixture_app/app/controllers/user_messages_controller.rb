class UserMessagesController < ApplicationController
  layout "student"
  before_action :authenticate_user!

  def index
    @messages = current_user.user_messages.order(:id)
    @message = current_user.user_messages.build
  end

  def create
    @message = current_user.user_messages.build(params.require(:user_message).permit(:body))
    if @message.save
      redirect_to user_messages_path, notice: t("messages.create.success")
    else
      @messages = current_user.user_messages.order(:id)
      render :index, status: :unprocessable_entity
    end
  end
end
