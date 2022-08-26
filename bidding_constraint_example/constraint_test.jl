using JuMP
using MathOptInterface
using Test
using Logging

@testset "Testing market bidding constraints" begin

include("constraint.jl")
# -- Creating instance --

S = scenarios(2)
T = time_steps(3)
time_series = [[1,2,3], [5.0, 6, 1]]
demand = [[-1,-2,-3], [-5.0, -6, -1]]
price = [[4.0, 4, 3], [6, 4, 2]]
efficiency = [[0.1, 0.1, 0.1], [0.2, 0.2, 0.2]]
cf = [[0.5, 0.5, 0.5], [0.1, 0.1, 0.1]]

# Declare test structure
structure = ModelStructure(S, T, [0.1, 0.9])

n1 = energy_node("n1", time_series, S, T)
n3 = storage_node("n3", 2.0, 6.0, 20.0, 0.5, demand, S, T, 10) #storage node has demand
n5 = commodity_node("n5", time_series, S, T)
n7 = market_node("n7", price, S, T)

p1 = flexible_process("p1", efficiency, S, T)
p3 = vre_process("p3", cf, S, T)
p5 = online_process("p5", efficiency, S, T, 0.1, 1, 1, 8.0, 1)

f_a = process_flow("n5", "p5", 30.0, 2.0, 0.1)
f_b = process_flow("n5", "p1", 30.0, 2.0, 0.2)
f_c = process_flow("p5", "n1", 5.0, 2.0, 0.2)
f_d = process_flow("p1", "n3", 6.0, 2.0, 0.1)
f_e = process_flow("p3", "n1", 8.0, 2.0, 1.0)
f_f = transfer_flow("n1", "n3")
f_g, f_h = market_flow("n1", "n7")

add_nodes!(structure, [n1, n3, n5, n7])
add_processes!(structure, [p1, p3, p5])
add_flows!(structure, [f_a, f_b, f_c, f_d, f_e, f_f, f_g, f_h])
validate_network(structure)

# Model initialisation
model = Model()
# Variable generation
f  = flow_variables(model, structure)
s = state_variables(model, structure)
shortage, surplus = shortage_surplus_variables(model, structure)
start, stop, online = start_stop_online_variables(model, structure)


@info "First set"
# Using data structure from constraints.jl
c10 = market_bidding_constraints(model, structure, f)

# Check constraint generated for each market (1), scenario comparisons (1) and time step (3)
@test length(c10) == 1 * 1 * 3

# Test that inequality constraint exists for scenario 1, scenario 2, time step 1 (since it has a lower price than s2,t1)
@test normalized_coefficient(c10["n7", 1, 2, 1], f["n1", "n7", 1, 1]) == 1
@test normalized_coefficient(c10["n7", 1, 2, 1], f["n7", "n1", 1, 1]) == -1
@test normalized_coefficient(c10["n7", 1, 2, 1], f["n1", "n7", 2, 1]) == -1
@test normalized_coefficient(c10["n7", 1, 2, 1], f["n7", "n1", 2, 1]) == 1
# Checking that this is inequality constraint
@test isa(c10["n7", 1, 2, 1], ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.LessThan{Float64}}, ScalarShape})

# Test that equality constraint exists for scenario 1,scenario 2, time step 2 (since it has a equal price to s2,t2)
@test normalized_coefficient(c10["n7", 1, 2, 2], f["n1", "n7", 1, 2]) == 1
@test normalized_coefficient(c10["n7", 1, 2, 2], f["n7", "n1", 1, 2]) == -1
@test normalized_coefficient(c10["n7", 1, 2, 2], f["n1", "n7", 2, 2]) == -1
@test normalized_coefficient(c10["n7", 1, 2, 2], f["n7", "n1", 2, 2]) == 1
# Checking that this is equality constraint
@test isa(c10["n7", 1, 2,2], ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.EqualTo{Float64}}, ScalarShape})



# -- Creating instance --
# Creating test structure for bidding constraints with more scenarios and time steps
S = scenarios(3)
T = time_steps(5)
structure = ModelStructure(S, T, [0.4, 0.3, 0.3])
time_series = [[1,2,3, 4, 5], [1.0,2.0,3.0, 4, 5], [4, 5.5, 6.6, 1, 1]]

# example nodes, two of each type
n1 = energy_node("n1", time_series, S, T)
n3 = storage_node("n3", 1.0, 1.0, 4.0, 0.1, time_series, S, T, 0.3)
n7 = market_node("n7", time_series, S, T)
n8 = market_node("n8", time_series, S, T)

# example flows
f5a, f5b = market_flow("n1", "n7")
f5c, f5d = market_flow("n3", "n8")

add_nodes!(structure, [n1, n3, n7, n8])
add_flows!(structure, [f5a, f5b, f5c, f5d])
validate_network(structure)

# Model, variable and bidding constraint generation
model = Model()
f  = flow_variables(model, structure)

@info "Second set"
c10 = market_bidding_constraints(model, structure, f)


@test length(c10) == 2 * 3 * 5

@test normalized_coefficient(c10["n7", 1, 2, 1], f["n1", "n7", 1, 1]) == 1
@test normalized_coefficient(c10["n7", 1, 2, 1], f["n7", "n1", 1, 1]) == -1
@test normalized_coefficient(c10["n7", 1, 2, 1], f["n1", "n7", 2, 1]) == -1
@test normalized_coefficient(c10["n7", 1, 2, 1], f["n7", "n1", 2, 1]) == 1

# Checking that this is equality constraints between scenarios 1 and 2 for all time steps
@test isa(c10["n7", 1, 2, 1], ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.EqualTo{Float64}}, ScalarShape})
@test isa(c10["n7", 1, 2, 2], ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.EqualTo{Float64}}, ScalarShape})
@test isa(c10["n7", 1, 2, 3], ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.EqualTo{Float64}}, ScalarShape})
@test isa(c10["n7", 1, 2, 4], ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.EqualTo{Float64}}, ScalarShape})
@test isa(c10["n7", 1, 2, 5], ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.EqualTo{Float64}}, ScalarShape})

# Checking that this is inequality constraints between scenarios 1 and 3 for all time steps (not price in scenario 3 is smaller for time steps 4 and 5)
@test isa(c10["n7", 1, 3, 1], ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.LessThan{Float64}}, ScalarShape})
@test isa(c10["n7", 1, 3, 2], ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.LessThan{Float64}}, ScalarShape})
@test isa(c10["n7", 1, 3, 3], ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.LessThan{Float64}}, ScalarShape})
@test isa(c10["n7", 3, 1, 4], ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.LessThan{Float64}}, ScalarShape})
@test isa(c10["n7", 3, 1, 5], ConstraintRef{Model, MathOptInterface.ConstraintIndex{MathOptInterface.ScalarAffineFunction{Float64}, MathOptInterface.LessThan{Float64}}, ScalarShape})

end