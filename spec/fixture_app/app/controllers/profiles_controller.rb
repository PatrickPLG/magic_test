class ProfilesController < ApplicationController
  layout "student"
  before_action -> { require_role!(Student) }

  def edit
    @student = current_role
  end

  def update
    @student = current_role
    attrs = params.require(:student).permit(:first_name, :last_name, :birthday, :gender, :newsletter, :country, :bio)
    if attrs[:birthday].present? && attrs[:birthday].include?("/")
      attrs[:birthday] = Date.strptime(attrs[:birthday], "%d/%m-%Y")
    end
    if @student.update(attrs)
      redirect_to edit_profile_path, notice: t("profile.update.success")
    else
      render :edit, status: :unprocessable_entity
    end
  end
end
