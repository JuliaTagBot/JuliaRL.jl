# JuliaRL
A simple repository for reinforcement learning julia codes.

For Julia v1.x

To run the mountain car test with Q-learning and tilecoding:

```
cd /path/to/JuliaRL/
julia
julia>]instantiate .
julia>]activate .
julia>include("test_tilecoder_mountaincar.jl")
julia>run()```


Due to some weirdness with OpenAIGym.jl you will have to install this dependency manually: https://github.com/JuliaML/OpenAIGym.jl.git
