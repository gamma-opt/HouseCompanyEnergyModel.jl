using JuMP


S = scenarios(2)
T = time_steps(3)
time_series = [[1,2,3], [5.0, 6, 1]]
price = [[4.0, 4, 3], [6, 4, 2]]
efficiency = [[0.1, 0.1, 0.1], [0.2, 0.2, 0.2]]
cf = [[0.5, 0.5, 0.5], [0.1, 0.1, 0.1]]

# Declare test structure
structure = ModelStructure(S, T, [0.1, 0.9])

n2 = plain_node("n2", time_series, S, T)
n3 = storage_node("n3", 2.0, 6.0, 20.0, 0.5, time_series, S, T, 10)
n5 = commodity_node("n5", time_series, S, T)
n7 = market_node("n7", price, S, T)

p1 = plain_unit_process("p1", efficiency, S, T)
p3 = cf_unit_process("p3", cf, S, T)
p5 = online_unit_process("p5", efficiency, S, T, 0.1, 1, 1, 8.0, 0)

f_a = process_flow("n5", "p5", time_series, S, T, 2.0, 0.1)
f_b = process_flow("n5", "p1", time_series, S, T, 2.0, 0.1)
f_c = process_flow("p5", "n1", time_series, S, T, 2.0, 0.1)
f_d = process_flow("p1", "n3", time_series, S, T, 2.0, 0.1)
f_e = process_flow("p3", "n1", time_series, S, T, 2.0, 0.1)
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


@info "\nConstraints:"

@info "Charging and discharging constraint"
c1,c2 = charging_discharging_constraints(model, structure, s)

# Check constraint generated for each node (1), scenario (2) and time step (3)
@test length(c1) == 1 * 2 * 3
@test length(c1) == length(c2)

# Check charging constraints
@test all(normalized_coefficient(c1["n3", sce, t], s["n3", sce, t]) == -1 for sce in S, t in T)
@test all(normalized_coefficient(c1["n3", sce, t], s["n3", sce, t-1]) == 0.5 for sce in S, t in 2:length(T))
#RHS = - n.in_flow_max - (1 - n.state_loss)*n.initial_state
RHS = -2.0 - 0.5 * 10
@test all(normalized_rhs(c1["n3", sce, 1]) == RHS for sce in S)
#RHS = - n.in_flow_max
RHS = -2.0
@test all(normalized_rhs(c1["n3", sce, t]) == RHS for sce in S, t in 2:length(T))


# Check discharging constraints
@test all(normalized_coefficient(c2["n3", sce, t], s["n3", sce, t]) == -1 for sce in S, t in T)
@test all(normalized_coefficient(c2["n3", sce, t], s["n3", sce, t-1]) == 0.5 for sce in S, t in 2:length(T))
# RHS = n.out_flow_max - (1 - n.state_loss)*n.initial_state
RHS = 6.0 - 0.5 * 10
@test all(normalized_rhs(c2["n3", sce, 1]) == RHS for sce in S)
# RHS = n.out_flow_max
RHS = 6.0
@test all(normalized_rhs(c2["n3", sce, t]) == RHS for sce in S, t in 2:length(T))



@info "Charging and discharging constraint"