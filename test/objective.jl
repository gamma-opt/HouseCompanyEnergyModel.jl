using JuMP


S = scenarios(2)
T = time_steps(3)
time_series = [[1,2,3], [5.0, 6, 1]]
efficiency = [[0.1, 0.1, 0.1], [0.2, 0.2, 0.2]]
cf = [[0.5, 0.5, 0.5], [0.1, 0.1, 0.1]]


@info "\nObjective function:"

@info "Commodity costs"
# Declare test structure
structure = ModelStructure(S, T, [0.1, 0.9])

n5 = commodity_node("n5", time_series, S, T)
n6 = commodity_node("n6", time_series, S, T)
n2 = plain_node("n2", time_series, S, T)
p1 = plain_unit_process("p1", efficiency, S, T)
f4 = transfer_flow("n5", "n2")
f9 = process_flow("n6", "p1", time_series, S, T, 1.0, 0.1)

add_nodes!(structure, [n2, n5, n6])
add_processes!(structure, [p1])
add_flows!(structure, [f4, f9])

validate_network(structure)

f  = flow_variables(model, structure)
shortage, surplus = shortage_surplus_variables(model, structure)

obj = declare_objective(model, structure, f, shortage, surplus)

@test coefficient(obj, f["n5", "n2", 1, 1]) == 0.1
@test coefficient(obj, f["n5", "n2", 2, 1]) == 0.2
@test coefficient(obj, f["n6", "p1", 3, 1]) ≈ 0.3
@test coefficient(obj, f["n5", "n2", 1, 2]) == 4.5
@test coefficient(obj, f["n6", "p1", 2, 2]) == 5.4
@test coefficient(obj, f["n5", "n2", 3, 2]) == 0.9

@info "Market costs"

n7 = market_node("n7", time_series, S, T)
n8 = market_node("n8", time_series, S, T)
n1 = plain_node("n1", time_series, S, T)
n3 = storage_node("n3", 1.0, 1.0, 1.0, 0.1, time_series, S, T, 0.3)
f5a, f5b = market_flow("n1", "n7")
f5c, f5d = market_flow("n3", "n8")

add_nodes!(structure, [n1, n3, n7, n8])
add_flows!(structure, [f5a, f5b, f5c, f5d])

f  = flow_variables(model, structure)
shortage, surplus = shortage_surplus_variables(model, structure)

obj = declare_objective(model, structure, f, shortage, surplus)

@test coefficient(obj, f["n7", "n1", 1, 1]) == 0.1
@test coefficient(obj, f["n7", "n1", 2, 1]) == 0.2
@test coefficient(obj, f["n8", "n3", 3, 1]) ≈ 0.3
@test coefficient(obj, f["n8", "n3", 1, 2]) == 4.5
@test coefficient(obj, f["n7", "n1", 2, 2]) == 5.4
@test coefficient(obj, f["n8", "n3", 3, 2]) == 0.9
@test coefficient(obj, f["n3", "n8", 3, 2]) == 0.0
@test coefficient(obj, f["n1", "n7", 3, 2]) == 0.0