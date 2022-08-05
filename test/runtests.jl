using Test
using Logging
using PredicerTestVersion

@testset "PredicerTestVersion" begin
    include("structures.jl")
    include("variables.jl")
    include("objective.jl")
end