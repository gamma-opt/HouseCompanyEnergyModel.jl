using JuMP
using MathOptInterface

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
n3 = storage_node("n3", 2, 6, 20, 0.5, demand, S, T, 10) #storage node has demand
n5 = commodity_node("n5", time_series, S, T)
n7 = market_node("n7", price, S, T)

p1 = flexible_process("p1", efficiency, cf, S, T, 0.2)
p3 = vre_process("p3", cf, S, T)
p5 = online_process("p5", efficiency, cf, S, T, 0.1, 1, 1, 0.2, 8.0, 1)

f_a = process_flow("n5", "p5", 30, 2)
f_b = process_flow("n5", "p1", 30, 2)
f_c = process_flow("p5", "n1", 5, 2)
f_d = process_flow("p1", "n3", 6, 2)
f_e = process_flow("p3", "n1", 8, 2)
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


@info "\n\tConstraints:"

@info "Charging and discharging constraint"
c1,c2 = charging_discharging_constraints(model, structure, s)

# Check constraint generated for each storage node (1), scenario (2) and time step (3)
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



@info "State balance constraints"
c3 = state_balance_constraints(model, structure, f, shortage, surplus, s)

# Check constraint generated for each storage and energy node (2), scenario (2) and time step (3)
@test length(c3) == 2 * 2 * 3

# Check variable coefficients in constraints
# storage node state variables
@test all(normalized_coefficient(c3["n3", sce, t], s["n3", sce, t]) == 1 for sce in S, t in T)
@test all(normalized_coefficient(c3["n3", sce, t], s["n3", sce, t-1]) == -0.5 for sce in S, t in 2:length(T))

# flow variables
@test all(normalized_coefficient(c3["n3", sce, t], f[source, "n3", sce, t]) == -1 for sce in S, t in T, source in ["n1", "p1"])
@test all(normalized_coefficient(c3["n1", sce, t], f[source, "n1", sce, t]) == -1 for sce in S, t in T, source in ["p3", "p5", "n7"])
@test all(normalized_coefficient(c3["n1", sce, t], f["n1", sink, sce, t]) == 1 for sce in S, t in T, sink in ["n3", "n7"])

# shortage and surplus variables
@test all(normalized_coefficient(c3[n, sce, t], shortage[n, sce, t]) == -1 for n in ["n1", "n3"], sce in S, t in T)
@test all(normalized_coefficient(c3[n, sce, t], surplus[n, sce, t]) == 1 for n in ["n1", "n3"], sce in S, t in T)

# constant (comes from external flow and for n3 also initial state)
# RHS = external_flow(t=1) + (1 - n.state_loss) * n.initial_state
RHS = [-1 + 0.5 *10, -5.0 + 0.5 *10]
@test all(normalized_rhs(c3["n3", sce, 1]) == RHS[sce] for sce in S)
# RHS = external_flow
@test all(normalized_rhs(c3["n3", sce, t]) == demand[sce][t] for sce in S, t in 2:length(T))
@test all(normalized_rhs(c3["n1", sce, t]) == time_series[sce][t] for sce in S, t in T)



@info "Process flow constraints"
c4 = process_flow_constraints(model, structure, f, online)

# Check constraint generated for each process flow (5), scenario (2) and time step (3)
@test length(c4) == 5 * 2 * 3

# process flows of flexible processes
@test string(c4["p1", "n3", 1, 1]) == "ConstraintRef[f(p1, n3, s1, t1) ∈ [0.0, 6.0]]"
@test string(c4["p1", "n3", 2, 2]) == "ConstraintRef[f(p1, n3, s2, t2) ∈ [0.0, 6.0]]"
@test string(c4["n5", "p1", 1, 3]) == "ConstraintRef[f(n5, p1, s1, t3) ∈ [0.0, 30.0]]"
@test string(c4["n5", "p1", 2, 3]) == "ConstraintRef[f(n5, p1, s2, t3) ∈ [0.0, 30.0]]"

# process flows of vre process
@test string(c4["p3", "n1", 1, 1]) == "ConstraintRef[f(p3, n1, s1, t1) ∈ [0.0, 4.0]]"
@test string(c4["p3", "n1", 1, 2]) == "ConstraintRef[f(p3, n1, s1, t2) ∈ [0.0, 4.0]]"
@test string(c4["p3", "n1", 1, 3]) == "ConstraintRef[f(p3, n1, s1, t3) ∈ [0.0, 4.0]]"
@test string(c4["p3", "n1", 2, 1]) == "ConstraintRef[f(p3, n1, s2, t1) ∈ [0.0, 0.8]]"
@test string(c4["p3", "n1", 2, 3]) == "ConstraintRef[f(p3, n1, s2, t3) ∈ [0.0, 0.8]]"

# flow variables of process flows of online process ([1] = lower bound, [2] = upper bound )
@test all(normalized_coefficient(c4[source, sink, sce, t][1], f[source, sink, sce, t]) == -1 for (source, sink) in [("n5", "p5"), ("p5", "n1")], sce in S, t in T)
@test all(normalized_coefficient(c4[source, sink, sce, t][2], f[source, sink, sce, t]) == 1 for (source, sink) in [("n5", "p5"), ("p5", "n1")], sce in S, t in T)


# online variables of process flows of online process
@test all(normalized_coefficient(c4["n5", "p5", sce, t][1], online["p5", sce, t]) == 0.1 * 30 for sce in S, t in T)
@test all(normalized_coefficient(c4["n5", "p5", sce, t][2], online["p5", sce, t]) == - 30.0 for sce in S, t in T)
@test all(normalized_coefficient(c4["p5", "n1", sce, t][1], online["p5", sce, t]) == 0.1 * 5 for sce in S, t in T)
@test all(normalized_coefficient(c4["p5", "n1", sce, t][2], online["p5", sce, t]) == - 5.0 for sce in S, t in T)




@info "Ramp rate constraints"
c5 = process_ramp_rate_constraints(model, structure, f, start, stop)

# Check constraint generated for each process flow connected to flexible or online process (4), scenario (2) and time steps 2:length(T) (2)
@test length(c5) == 4 * 2 * 2

# flexible process constant ramp rates
@test string(c5["n5", "p1", 2, 2]) == "ConstraintRef[-f(n5, p1, s2, t1) + f(n5, p1, s2, t2) ∈ [-6.0, 6.0]]"
@test string(c5["n5", "p1", 2, 3]) == "ConstraintRef[-f(n5, p1, s2, t2) + f(n5, p1, s2, t3) ∈ [-6.0, 6.0]]"
@test string(c5["p1", "n3", 1, 2]) == "ConstraintRef[-f(p1, n3, s1, t1) + f(p1, n3, s1, t2) ∈ [-0.6000000000000001, 0.6000000000000001]]"
@test string(c5["p1", "n3", 1, 3]) == "ConstraintRef[-f(p1, n3, s1, t2) + f(p1, n3, s1, t3) ∈ [-0.6000000000000001, 0.6000000000000001]]"

# online process ramp rates ([1] = lower bound, [2] = upper bound )
# flow variable coefficients
@test all(normalized_coefficient(c5[source, sink, sce, t][1], f[source, sink, sce, t]) == -1 for (source, sink) in [("n5", "p5"), ("p5", "n1")], sce in S, t in 2:length(T))
@test all(normalized_coefficient(c5[source, sink, sce, t][1], f[source, sink, sce, t-1]) == 1 for (source, sink) in [("n5", "p5"), ("p5", "n1")], sce in S, t in 2:length(T))
@test all(normalized_coefficient(c5[source, sink, sce, t][2], f[source, sink, sce, t]) == 1 for (source, sink) in [("n5", "p5"), ("p5", "n1")], sce in S, t in 2:length(T))
@test all(normalized_coefficient(c5[source, sink, sce, t][2], f[source, sink, sce, t-1]) == -1 for (source, sink) in [("n5", "p5"), ("p5", "n1")], sce in S, t in 2:length(T))


# stop variable coefficient in lower bound
@test all(normalized_coefficient(c5["n5", "p5", sce, t][1], stop["p5", sce, t]) == -(0.1*30.0 - 0.1) for sce in S, t in 2:length(T))
@test all(normalized_coefficient(c5["p5", "n1", sce, t][1], stop["p5", sce, t]) == -(0.1*5.0 - 0.2) for sce in S, t in 2:length(T))

# start variable coefficient in upper bound
@test all(normalized_coefficient(c5["n5", "p5", sce, t][2], start["p5", sce, t]) == -(0.1*30.0 - 0.1) for sce in S, t in 2:length(T))
@test all(normalized_coefficient(c5["p5", "n1", sce, t][2], start["p5", sce, t]) == -(0.1*5.0 - 0.2) for sce in S, t in 2:length(T))


@info "Efficiency constraints"
c6 = process_efficiency_constraints(model, structure, f)

# Check constraint generated for each flexible and online process (2), scenario (2) and time step (3)
@test length(c6) == 2 * 2 * 3

# Efficiency of process p1
@test all(normalized_coefficient(c6["p1", sce, t], f["p1", "n3", sce, t]) == 1 for sce in S, t in T)
@test all(normalized_coefficient(c6["p1", sce, t], f["n5", "p1", sce, t]) == -efficiency[sce][t] for sce in S, t in T)
@test all(normalized_rhs(c6["p1", sce, t]) == 0.0 for sce in S, t in T)

# Efficiency of process p5
@test all(normalized_coefficient(c6["p5", sce, t], f["p5", "n1", sce, t]) == 1 for sce in S, t in T)
@test all(normalized_coefficient(c6["p5", sce, t], f["n5", "p5", sce, t]) == -efficiency[sce][t] for sce in S, t in T)
@test all(normalized_rhs(c6["p5", sce, t]) == 0.0 for sce in S, t in T)



@info "Online functionality constraints"
c7, c8, c9 = online_functionality_constraints(model, structure, start, stop, online)

# Check constraint generated for each online process (1), scenario (2) and time step (3)
@test length(c7) == 1 * 2 * 3
@test length(c8) == 1 * 2 * 3
@test length(c9) == 1 * 2 * 3

# Check on/off constraint initial status
@test all(normalized_coefficient(c7["p5", sce, 1], online["p5", sce, 1]) == p5.initial_status for sce in S)

# Check on/off constraint rest of time steps
@test all(normalized_coefficient(c7["p5", sce, t], online["p5", sce, t]) == 1 for sce in S, t in 2:length(T))
@test all(normalized_coefficient(c7["p5", sce, t], online["p5", sce, t-1]) == -1 for sce in S, t in 2:length(T))
@test all(normalized_coefficient(c7["p5", sce, t], start["p5", sce, t]) == -1 for sce in S, t in 2:length(T))
@test all(normalized_coefficient(c7["p5", sce, t], stop["p5", sce, t]) == 1 for sce in S, t in 2:length(T))

# Check min online constraint (min online time of p5 is 1, thus checking t and t+1 online variables)
@test all(normalized_coefficient(c8["p5", sce, t][1], online["p5", sce, t]) == 1 for sce in S, t in T)
@test all(normalized_coefficient(c8["p5", sce, t][2], online["p5", sce, t+1]) == 1 for sce in S, t in 1:2)
@test all(normalized_coefficient(c8["p5", sce, t][1], start["p5", sce, t]) == -1 for sce in S, t in T)
@test all(normalized_coefficient(c8["p5", sce, t][2], start["p5", sce, t]) == -1 for sce in S, t in 1:2)

# Check min offline constraint (min online time of p5 is 1, thus checking t and t+1 online variables)
@test all(normalized_coefficient(c9["p5", sce, t][1], online["p5", sce, t]) == 1 for sce in S, t in T)
@test all(normalized_coefficient(c9["p5", sce, t][2], online["p5", sce, t+1]) == 1 for sce in S, t in 1:2)
@test all(normalized_coefficient(c9["p5", sce, t][1], stop["p5", sce, t]) == 1 for sce in S, t in T)
@test all(normalized_coefficient(c9["p5", sce, t][2], stop["p5", sce, t]) == 1 for sce in S, t in 1:2)
@test all(normalized_rhs(c9["p5", sce, t][1]) == 1 for sce in S, t in T)
@test all(normalized_rhs(c9["p5", sce, t][2]) == 1 for sce in S, t in 1:2)


