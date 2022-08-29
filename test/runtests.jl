using Test
using Logging
using HouseCompanyEnergyModel

@testset "PredicerTestVersion" begin
    include("structures.jl")
    include("variables.jl")
    include("constraints.jl")
    include("objective.jl")
end