using JuMP
using MathOptInterface

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
