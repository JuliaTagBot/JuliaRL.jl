module LinearRL

using LinearAlgebra

export StateValueFunction, Optimizer, TD, WISTD, VtraceTD, TDC, GTD2, update!

abstract type AbstractValueFunction end
abstract type Optimizer end

"""
update!(value::ValueFunction, opt::Optimizer, ρ, s_t, s_tp1, reward, γ, terminal)

# Arguments:
`value::ValueFunction`:
`opt::Optimizer`:
`ρ`: Importance sampling ratios (Array of Floats)
`s_t`: States at time t
`s_tp1`: States at time t + 1
`reward`: cumulant or reward for value function
`γ`: discount factor
`terminal`: Determining termination of the episode (if applicable).
"""
function update!(value::AbstractValueFunction, opt::Optimizer, ϕ_t, ϕ_tp1, reward, γ, ρ, terminal)
    throw(ErrorException("Implement update for $(typeof(opt))"))
end

function update!(value::AbstractValueFunction, opt::Optimizer, ϕ_t, ϕ_tp1, reward, γ, ρ, terminal, a_t, a_tp1, target_policy)
    throw(ErrorException("Implement update for $(typeof(opt))"))
end

abstract type AbstractVFunction end

mutable struct VFunction <: AbstractVFunction
    weights::Array{Float64}
    h::Array{Float64}
    StateValueFunction(num_features::Integer) = new(zeros(num_features), zeros(num_features))
end

mutable struct SparseVFunction <: AbstractVFunction
    weights::Array{Float64}
    h::Array{Float64}
    StateValueFunction(num_features::Integer) = new(zeros(num_features), zeros(num_features))
end

(value::VFunction)(ϕ) = dot(value.weights, ϕ)
(value::SparseVFunction)(ϕ) = sum(value.weights[ϕ])

update!(value::AbstractVFunction, ϕ, δ) = throw("Implement update for value function")
update!(value::VFunction, ϕ, δ) = value.weights .+= δ.*ϕ
update!(value::SparseVFunction, ϕ, δ) = value.weights[ϕ] .+= δ

update!(value::AbstractVFunction, Δθ) = value.weights .+= Δθ

function update!(value::AbstractVFunction, opt::Optimizer, s_t, s_tp1, r, γ, ρ, terminal, a_t, a_tp1, target_policy)
    update!(value, opt, s_t, s_tp1, r, γ, ρ, terminal)
    # println("Hello World")
end
mutable struct OnlineTD <: Optimizer
    α::Float64
end

function update!(value::AbstractVFunction, opt::OnlineTD, ϕ_t, ϕ_tp1, r, γ, ρ, terminal)
    α = opt.α
    δ = r + γ*values(ϕ_t) - value(ϕ_t)
    Δθ = (α*ρ*δ)
    update!(value, ϕ_t, Δθ)
end

mutable struct BatchTD <: Optimizer
    α::Float64
    α_mod::Float64
    avg::Bool
    TD(α, α_mod, avg) = new(α, α_mod, avg)
end

function update!(value::VFunction, opt::BatchTD, s_t, s_tp1, r, γ, ρ, terminal)
    α = opt.α*opt.α_mod
    if opt.avg
        α = α/length(ρ)
    end
    # α = TD.α*TD.α_mod
    δ = r + γ.*(dot.(s_tp1, [value.weights])) - dot.(s_t, [value.weights])
    # println(ρ)
    # println(s_t)
    Δθ = α*sum(ρ.*(δ.*s_t))

    # println(Δθ)
    value.weights .+= Δθ
end

mutable struct BatchTDC <: Optimizer
    α::Float64
    β::Float64
    α_mod::Float64
    β_mod::Float64
    avg::Bool
    # TDC(α, β) = new(α, β, 1.0, 1.0, true)
    # TDC(α, β, α_mod, β_mod, avg) = new(α, β, α_mod, β_mod, avg)
end

function update!(value::VFunction, opt::BatchTDC, s_t, s_tp1, r, γ, ρ, terminal)
    # α = TD.α*TD.α_mod
    # β = TD.β*TD.β_mod

    α = opt.α*opt.α_mod
    β = opt.β*opt.β_mod
    if opt.avg
        α = α/length(ρ)
        β = β/length(ρ)
    end

    δ = r + γ.*(dot.(s_tp1, [value.weights])) - dot.(s_t, [value.weights])
    Δθ = α*sum(ρ.*(δ.*s_t - γ.*dot.(s_t, [value.h]).*s_tp1))
    Δh = β*sum(s_t.*(ρ.*δ - dot.(s_t, [value.h])))

    value.weights .+= Δθ
    value.h .+= Δh
end

mutable struct WISBatchTDC <: Optimizer
    α::Float64
    β::Float64
    α_mod::Float64
    β_mod::Float64
    WISTDC(α, β) = new(α, β, 1.0, 1.0)
end

function update!(value::VFunction, opt::WISBatchTDC, s_t, s_tp1, r, γ, ρ, terminal)
    δ = r + γ.*(dot.(s_tp1, [value.weights])) - dot.(s_t, [value.weights])
    Δθ = α*sum(ρ.*(δ.*s_t - γ.*dot.(s_t, [value.h]).*s_tp1))
    Δh = β*sum(s_t.*(ρ.*δ - dot.(s_t, [value.h])))

    value.weights .+= Δθ./sum(ρ)
    value.h .+= Δh./sum(ρ)
end

mutable struct BatchTDC2 <: Optimizer
    α::Float64
    β::Float64
    α_mod::Float64
    β_mod::Float64
    avg::Bool
    TDC2(α, β) = new(α, β, 1.0, 1.0, true)
end

function update!(value::VFunction, opt::BatchTDC2, s_t, s_tp1, r, γ, ρ, terminal)
    # Python code sample = (prev_phi.copy(), phi.copy(), action, reward, state, prev_state, pi[action]/mu[action])
    # td_error = (sample[3] + gamma*(sample[1].dot(weights_tdc_iwer)) - sample[0].dot(weights_tdc_iwer))
    # weights_tdc_iwer = weights_tdc_iwer + alpha*sample[-1]*(td_error*sample[0] - gamma*sample[1]*(sample[0].dot(h_tdc_iwer)))
    # h_tlndc_iwer = h_tdc_iwer + alpha_h*(sample[-1]*td_error - sample[0].dot(h_tdc_iwer))*sample[0]
    α = opt.α*opt.α_mod
    β = opt.β*opt.β_mod
    if opt.avg
        α = α/length(ρ)
        β = β/length(ρ)
    end

    δ = r + γ.*(dot.(s_tp1, [value.weights])) - dot.(s_t, [value.weights])
    Δθ = α*sum(ρ.*(δ.*s_t - γ.*dot.(s_t, [value.h]).*s_tp1))
    Δh = β*sum(s_t.*(ρ.*(δ - dot.(s_t, [value.h]))))

    value.weights .+= Δθ
    value.h .+= Δh
end

mutable struct BatchGTD2 <: Optimizer
    α::Float64
    β::Float64
    α_mod::Float64
    β_mod::Float64
    avg::Bool
    GTD2(α, β) = new(α, β, 1.0, 1.0, true)
    GTD2(α, β, α_mod, β_mod, avg) = new(α, β, α_mod, β_mod, avg)
end

function update!(value::VFunction, opt::BatchGTD2, s_t, s_tp1, r, γ, ρ, terminal)
    # Python code sample = (prev_phi.copy(), phi.copy(), action, reward, state, prev_state, pi[action]/mu[action])
    # td_error = (sample[3] + gamma*(sample[1].dot(weights_gtd2_iwer)) - sample[0].dot(weights_gtd2_iwer))
    # weights_gtd2_iwer = weights_gtd2_iwer + alpha*sample[-1]*(sample[0] - gamma*sample[1])*(sample[0].dot(h_gtd2_iwer))
    # h_gtd2_iwer = h_gtd2_iwer + alpha_h*(sample[-1]*td_error - sample[0].dot(h_gtd2_iwer))*sample[0]
    α = opt.α*opt.α_mod
    β = opt.β*opt.β_mod
    if opt.avg
        α = α/length(ρ)
        β = β/length(ρ)
    end

    δ = r + γ.*(dot.(s_tp1, [value.weights])) - dot.(s_t, [value.weights])
    Δθ = α*sum(ρ.*(s_t - γ.*s_tp1).*(dot.(s_t, [value.h])))
    Δh = β*sum(s_t.*(ρ.*δ - dot.(s_t, [value.h])))

    value.weights .+= Δθ
    value.h .+= Δh
end


"""
Action state value functions.

"""

export QFunction, SparseQFunction, get_values, WatkinsQ, watkins_q_target

abstract type AbstractQFunction end

mutable struct QFunction <: AbstractQFunction
    weights::Array{Float64}
    h::Array{Float64}
    num_features_per_action::Integer
    num_actions::Integer
    QFunction(num_features::Integer, num_features_per_action::Integer, num_actions::Integer) =
        new(zeros(num_features), zeros(num_features), num_features_per_action, num_actions)
end

mutable struct SparseQFunction <: AbstractQFunction
    weights::Array{Float64}
    h::Array{Float64}
    num_features_per_action::Integer
    num_actions::Integer
    SparseQFunction(num_features::Integer, num_features_per_action::Integer, num_actions::Integer) =
        new(zeros(num_features), zeros(num_features), num_features_per_action, num_actions)
end

# Get values for QFunction
(value::QFunction)(ϕ, action) =
    dot(value.weights[(value.num_features_per_action*(action-2) + 1):(value.num_features_per_action*(action-1) + 1)], ϕ)

# Get values for Sparse Q Function
(value::SparseQFunction)(ϕ, action) =
    sum(value.weights[ϕ .+ (value.num_features_per_action*(action-1) + 1)])

get_values(value::AbstractQFunction, ϕ) = [value(ϕ, a) for a in 1:value.num_actions]

update!(value::AbstractQFunction, ϕ, action, δ) = throw("Define Update Function for Q Function")
update!(value::QFunction, ϕ, action, δ) = value.weights[(value.num_features_per_action*(action-2) + 1):(value.num_features_per_action*(action-1) + 1)] .+= δ*ϕ
update!(value::SparseQFunction, ϕ, action, δ) = value.weights[ϕ .+ (value.num_features_per_action*(action-1) + 1)] .+= δ

mutable struct WatkinsQ
    α::Float64
end
watkins_q_target(q::AbstractQFunction, ϕ, r) = r + maximum([q(ϕ, a) for a = 1:q.num_actions])

function update!(value::AbstractQFunction, opt::WatkinsQ, ϕ_t, ϕ_tp1, r, γ, ρ, terminal, a_t, a_tp1=nothing, target_policy=nothing)
    α = opt.α
    δ = watkins_q_target(value, ϕ_tp1, r) - value(ϕ_t, a_t)
    Δθ = α*δ
    update!(value, ϕ_t, a_t, Δθ)
end


end
