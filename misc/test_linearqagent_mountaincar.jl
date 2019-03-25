# using Flux
using Pkg

Pkg.activate(".")


using JuliaRL

using Random
using ProgressMeter

function test_run(α=0.5/8, ϵ=0.1, γ=1.0, tilings=32, tiles=2; n_episodes=1000, seed=1002349)

    # ϵ = 0.1
    # α = 0.5/tilings
    size_env_state = 2
    num_actions = 3

    lu = Learning.LinearRL.WatkinsQ(α)
    policy = EpsilonGreedyQPolicy(ϵ, 1:3)
    agent = Agent.TileCoderAgent(lu, size_env_state, num_actions, tilings, tiles, γ, policy)


    rng = Random.MersenneTwister(seed)
    env = MountainCar(rng)
    cumulative_reward_array = zeros(Int64, n_episodes)
    # println("Here")
    @showprogress 0.1 "Episode: " for episode = 1:n_episodes
    # for episode = 1:n_episodes
        terminal = false
        num_steps = 0
        cumulative_reward = 0
        _, state = start!(env; rng=rng)
        action = Agent.start!(agent, state; rng=rng)
        while !terminal
            # print(num_steps, "\r")
            _, state_prime, reward, terminal = step!(env, action; rng=rng)

            action = Agent.step!(agent, state_prime, reward, terminal; rng=rng)
            # println(action)
            # println(reward)
            num_steps += 1
            cumulative_reward += reward

        end
        cumulative_reward_array[episode] = cumulative_reward
    end
    return cumulative_reward_array
end
