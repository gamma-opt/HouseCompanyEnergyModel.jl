using JuMP


S = scenarios(2)
T = time_steps(3)
time_series = [[1,2,3], [5.0, 6, 1]]
price = [[4.0, 4, 3], [6, 4, 2]]
efficiency = [[0.1, 0.1, 0.1], [0.2, 0.2, 0.2]]
cf = [[0.5, 0.5, 0.5], [0.1, 0.1, 0.1]]

# Declare test structure
structure = ModelStructure(S, T, [0.1, 0.9])


@info "\nObjective function:"

@info "Commodity costs"
n5 = commodity_node("n5", time_series, S, T)
n6 = commodity_node("n6", time_series, S, T)
n2 = plain_node("n2", time_series, S, T)
p1 = plain_unit_process("p1", efficiency, S, T)
f4 = transfer_flow("n5", "n2")
f9 = process_flow("n6", "p1", time_series, S, T, 0.0, 0.1)

add_nodes!(structure, [n2, n5, n6])
add_processes!(structure, [p1])
add_flows!(structure, [f4, f9])
validate_network(structure)

model = Model()
f  = flow_variables(model, structure)
shortage, surplus = shortage_surplus_variables(model, structure)

obj = declare_objective(model, structure, f, shortage, surplus, 100.0)

@test coefficient(obj, f["n5", "n2", 1, 1]) == 0.1
@test coefficient(obj, f["n5", "n2", 1, 2]) == 0.2
@test coefficient(obj, f["n6", "p1", 1, 3]) ≈ 0.3
@test coefficient(obj, f["n5", "n2", 2, 1]) == 4.5
@test coefficient(obj, f["n6", "p1", 2, 2]) == 5.4
@test coefficient(obj, f["n5", "n2", 2, 3]) == 0.9




@info "Market costs"
n7 = market_node("n7", price, S, T)
n8 = market_node("n8", price, S, T)
n1 = plain_node("n1", time_series, S, T)
n3 = storage_node("n3", 1.0, 1.0, 1.0, 0.1, time_series, S, T, 0.3)
f5a, f5b = market_flow("n1", "n7")
f5c, f5d = market_flow("n3", "n8")

add_nodes!(structure, [n1, n3, n7, n8])
add_flows!(structure, [f5a, f5b, f5c, f5d])
validate_network(structure)

model = Model()
f  = flow_variables(model, structure)
shortage, surplus = shortage_surplus_variables(model, structure)

obj = declare_objective(model, structure, f, shortage, surplus, 100.0)

@test coefficient(obj, f["n7", "n1", 1, 1]) == 0.4
@test coefficient(obj, f["n7", "n1", 1, 2]) == 0.4
@test coefficient(obj, f["n8", "n3", 1, 3]) ≈ 0.3
@test coefficient(obj, f["n8", "n3", 2, 1]) == 5.4
@test coefficient(obj, f["n7", "n1", 2, 2]) == 3.6
@test coefficient(obj, f["n8", "n3", 2, 3]) == 1.8

@test coefficient(obj, f["n1", "n7", 1, 1]) == 0.4
@test coefficient(obj, f["n1", "n7", 1, 2]) == 0.4
@test coefficient(obj, f["n3", "n8", 1, 3]) ≈ 0.3
@test coefficient(obj, f["n3", "n8", 2, 1]) == 5.4
@test coefficient(obj, f["n1", "n7", 2, 2]) == 3.6
@test coefficient(obj, f["n3", "n8", 2, 3]) == 1.8




@info "VOM costs"
p3 = cf_unit_process("p3", cf, S, T)
p5 = online_unit_process("p5", efficiency, S, T, 0.1, 1, 1, 8.0, 0)
f10 = process_flow("p3", "n2", time_series, S, T, 10.0, 0.1)
f11a = process_flow("n5", "p5", time_series, S, T, 2.0, 0.1)

add_processes!(structure, [p3, p5])
add_flows!(structure, [f10, f11a])
validate_network(structure)

model = Model()
f  = flow_variables(model, structure)
shortage, surplus = shortage_surplus_variables(model, structure)
start, stop, online = start_stop_online_variables(model, structure)
obj = declare_objective(model, structure, f, shortage, surplus, 100.0, start)

@test coefficient(obj, f["p3", "n2", 1, 1]) == 1.0
@test coefficient(obj, f["p3", "n2", 1, 2]) == 1.0
@test coefficient(obj, f["p3", "n2", 1, 3]) == 1.0
@test coefficient(obj, f["p3", "n2", 2, 1]) == 9
@test coefficient(obj, f["p3", "n2", 2, 2]) == 9
@test coefficient(obj, f["p3", "n2", 2, 3]) == 9

# these flows also have commodity costs + VOM costs because n5 is a commodity node
@test coefficient(obj, f["n5", "p5", 1, 1]) == 0.1 + 0.2
@test coefficient(obj, f["n5", "p5", 1, 2]) == 0.2 + 0.2
@test coefficient(obj, f["n5", "p5", 1, 3]) == 0.3 + 0.2
@test coefficient(obj, f["n5", "p5", 2, 1]) == 4.5 + 1.8
@test coefficient(obj, f["n5", "p5", 2, 2]) == 5.4 + 1.8
@test coefficient(obj, f["n5", "p5", 2, 3]) == 0.9 + 1.8



@info "Start costs"
@test coefficient(obj, start["p5", 1, 1]) == 0.8
@test coefficient(obj, start["p5", 1, 2]) == 0.8
@test coefficient(obj, start["p5", 1, 3]) == 0.8
@test coefficient(obj, start["p5", 2, 1]) == 7.2
@test coefficient(obj, start["p5", 2, 2]) == 7.2
@test coefficient(obj, start["p5", 2, 3]) == 7.2



@info "Penalty costs"
# plain nodes
@test coefficient(obj, shortage["n1", 1, 1]) == 10
@test coefficient(obj, shortage["n1", 1, 2]) == 10
@test coefficient(obj, surplus["n1", 1, 3]) == 10
@test coefficient(obj, surplus["n1", 2, 1]) == 90
@test coefficient(obj, surplus["n1", 2, 2]) == 90
@test coefficient(obj, shortage["n1", 2, 3]) == 90

@test coefficient(obj, shortage["n2", 1, 1]) == 10
@test coefficient(obj, shortage["n2", 1, 2]) == 10
@test coefficient(obj, surplus["n2", 1, 3]) == 10
@test coefficient(obj, surplus["n2", 2, 1]) == 90
@test coefficient(obj, surplus["n2", 2, 2]) == 90
@test coefficient(obj, shortage["n2", 2, 3]) == 90

# commodity node
@test coefficient(obj, shortage["n3", 1, 1]) == 10
@test coefficient(obj, shortage["n3", 1, 2]) == 10
@test coefficient(obj, surplus["n3", 1, 3]) == 10
@test coefficient(obj, surplus["n3", 2, 1]) == 90
@test coefficient(obj, surplus["n3", 2, 2]) == 90
@test coefficient(obj, shortage["n3", 2, 3]) == 90