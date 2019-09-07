
"""
    AbstractDiscount

An abstract type for discount functions in GVFs.
"""
abstract type AbstractDiscount end

function get(γ::AbstractDiscount, state_t, action_t, state_tp1, action_tp1, preds_tp1)
    throw(DomainError("get(DiscountType, args...) not defined!"))
end

"""
    ConstantDiscount{T} <: AbstractDiscount

Always returns a constant value γ
"""
struct ConstantDiscount{T} <: AbstractDiscount
    γ::T
end

get(cd::ConstantDiscount, state_t, action_t, state_tp1, action_tp1, preds_tp1) = cd.γ

"""
    StateTerminationDiscount{T<:Number, F} <: AbstractDiscount

Returns 0 if the condition is true and γ otherwise.
"""
struct StateTerminationDiscount{T<:Number, F} <: AbstractDiscount
    γ::T
    condition::F
    terminal::T

end

StateTerminationDiscount(γ, condition) =
    new(γ, condition, zero(γ))

get(td::StateTerminationDiscount, state_t, action_t, state_tp1, action_tp1, preds_tp1) =
    td.condition(state_tp1) ? td.terminal : td.γ