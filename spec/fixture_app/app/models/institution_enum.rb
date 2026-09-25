# Studiz keeps its enums as constants; `InstitutionEnum::EmployeeType[:leader]`
# is the leader lookup its sign-in helper uses (Appendix A).
module InstitutionEnum
  EmployeeType = {employee: "employee", leader: "leader"}.freeze # rubocop:disable Naming/ConstantName -- Studiz's name
end
