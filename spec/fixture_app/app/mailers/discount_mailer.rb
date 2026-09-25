class DiscountMailer < ActionMailer::Base
  default from: "noreply@studiz.example"

  def reminder(discount)
    @discount = discount
    mail(to: discount.provider.user.email, subject: "Påmindelse: #{discount.name_da}")
  end
end
