# Studiz runs Sidekiq; specs fake it (rspec-sidekiq), so this only runs inside
# `Sidekiq::Testing.inline!` or when a spec drains the queue.
class ReminderFollowUpJob
  include Sidekiq::Job

  def perform(discount_id)
    discount = Discount.find(discount_id)
    Note.create!(notable: discount, body: "Opfølgning planlagt")
  end
end
