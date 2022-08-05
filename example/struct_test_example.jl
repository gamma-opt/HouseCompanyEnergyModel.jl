using Revise; 
using JuMP; 
using Gurobi; 
using PredicerTestVersion

# recreating the structure from structures.jl tests.
S = scenarios(2)
T = time_steps(3)
structure = ModelStructure(S, T, [0.1, 0.9])


time_series = [[1,2,3], [5.0, 6, 1]]
efficiency = [[0.1, 0.1, 0.1], [0.2, 0.2, 0.2]]
cf = [[0.5, 0.5, 0.5], [0.1, 0.1, 0.1]]

# example nodes, two of each type
n1 = plain_node("n1", time_series, S, T)
n2 = plain_node("n2", time_series, S, T)
n3 = storage_node("n3", 1.0, 1.0, 1.0, 0.1, time_series, S, T, 0.3)
n4 = storage_node("n4", 1.0, 1.0, 1.0, 0.1, time_series, S, T, 0.4)
n5 = commodity_node("n5", time_series, S, T)
n6 = commodity_node("n6", time_series, S, T)
n7 = market_node("n7", time_series, S, T)
n8 = market_node("n8", time_series, S, T)

# example processes, two of each type
p1 = plain_unit_process("p1", efficiency, S, T)
p2 = plain_unit_process("p2", efficiency, S, T)
p3 = cf_unit_process("p3", cf, S, T)
p4 = cf_unit_process("p4", cf, S, T)
p5 = online_unit_process("p5", efficiency, S, T, 0.1, 1, 1, 1.1, 0)
p6 = online_unit_process("p6", efficiency, S, T, 0.1, 1, 1, 1.1, 0)

# example flows
f1 = transfer_flow("n1", "n2")
f2 = transfer_flow("n2", "n3")
f4 = transfer_flow("n5", "n2")
f5a, f5b = market_flow("n1", "n7")
f5c, f5d = market_flow("n3", "n8")
f9 = process_flow("n6", "p1", time_series, S, T, 1.0, 0.1)
f10 = process_flow("p3", "n2", time_series, S, T, 1.0, 0.1)
f11a = process_flow("n5", "p5", time_series, S, T, 1.0, 0.1)
f11b = process_flow("p6", "n3", time_series, S, T, 1.0, 0.1)
f15 = process_flow("p2", "n4", time_series, S, T, 1.0, 0.1)
f16 = process_flow("p4", "n4", time_series, S, T, 1.0, 0.1)

add_nodes!(structure, [n1, n2, n3, n4, n5, n6, n7, n8])
add_processes!(structure, [p1, p2, p3, p4, p5, p6])
add_flows!(structure, [f1, f2, f4, f5a, f5b, f5c, f5d, f9, f10, f11a, f11b, f15, f16])

validate_network(structure)

# Model initialisation
model = Model()

# Variable generation
f  = flow_variables(model, structure)
s = state_variables(model, structure)
shortage, surplus = shortage_surplus_variables(model, structure)
start, stop, online = start_stop_online_variables(model, structure)

# Constraint generation
c1,c2 = charging_discharging_constraints(model, structure, s)
c3 = state_balance_constraints(model, structure, f, shortage, surplus, s)
c4 = process_flow_bound_constraints(model, structure, f, online)
c5 = process_ramp_rate_constraints(model, structure, f, start, stop)
c6 = process_efficiency_constraints(model, structure, f)
c7, c8, c9 = online_functionality_constraints(model, structure, start, stop, online)
c10 = market_bidding_constraints(model, structure, f)


# Objective function
obj = declare_objective(model, structure, f, shortage, surplus)

# optimizer = optimizer_with_attributes(
#     () -> Gurobi.Optimizer(Gurobi.Env()),
#     "IntFeasTol"      => 1e-6,
# )
# set_optimizer(model, optimizer)

# optimize!(model)