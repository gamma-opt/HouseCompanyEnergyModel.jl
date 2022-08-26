using JuMP
# recreating the structure from structures.jl tests.
structure = ModelStructure(scenarios(3), time_steps(5), [0.4, 0.3, 0.3])

time_series = [[1,2,3, 4, 5], [1.0,2.0,3.0, 4, 5], [4, 5.5, 6.6, 1, 1]]
efficiency = [[0.1, 0.1, 0.1, 0.1, 0.1], [0.1, 0.1, 0.1, 0.1, 0.1], [0.1, 0.1, 0.1, 0.1, 0.1]]
cf = [[0.1, 0.1, 0.1, 0.1, 0.1], [0.1, 0.1, 0.1, 0.1, 0.1], [0.1, 0.1, 0.1, 0.1, 0.1]]

# example nodes, two of each type
n1 = energy_node("n1", time_series, S, T)
n2 = energy_node("n2", time_series, S, T)
n3 = storage_node("n3", 1, 1, 4, 0.1, time_series, S, T, 0.3)
n4 = storage_node("n4", 1.0, 1.0, 5.0, 0.1, time_series, S, T, 0.4)
n5 = commodity_node("n5", time_series, S, T)
n6 = commodity_node("n6", time_series, S, T)
n7 = market_node("n7", time_series, S, T)
n8 = market_node("n8", time_series, S, T)

# example processes, two of each type
p1 = flexible_process("p1", efficiency, cf, S, T, 0.2)
p2 = flexible_process("p2", efficiency, cf, S, T, 0.2)
p3 = vre_process("p3", cf, S, T)
p4 = vre_process("p4", cf, S, T)
p5 = online_process("p5", efficiency, cf, S, T, 0.1, 1, 1, 0.2, 3, 0)
p6 = online_process("p6", efficiency, cf, S, T, 0.1, 1, 1, 0, 1, 0)

# example flows
f1 = transfer_flow("n1", "n2")
f2 = transfer_flow("n2", "n3")
f4 = transfer_flow("n5", "n2")
f5a, f5b = market_flow("n1", "n7")
f5c, f5d = market_flow("n3", "n8")
f9 = process_flow("n6", "p1", 2.0, 1.0)
f10 = process_flow("p3", "n2", 2.0, 1.0)
f11a = process_flow("n5", "p5", 2.0, 1.0)
f11b = process_flow("p6", "n3", 2.0, 1.0)
f15 = process_flow("p2", "n4", 2.0, 1.0)
f16 = process_flow("p4", "n4", 2.0, 1.0)

add_nodes!(structure, [n1, n2, n3, n4, n5, n6, n7, n8])
add_processes!(structure, [p1, p2, p3, p4, p5, p6])
add_flows!(structure, [f1, f2, f4, f5a, f5b, f5c, f5d, f9, f10, f11a, f11b, f15, f16])

validate_network(structure)

model = Model()

@info "\n\tVariable generation:"


@info "Testing flow variables"
f = flow_variables(model, structure)

@test !isempty(f)
# check all 13 flows have a variable
@test length(f) == 13*3*5

@test isa(f["n1", "n2", 1, 2], VariableRef)
@test isa(f["n1", "n2", 3, 5], VariableRef)

@test string(f["n1", "n2", 2, 1]) == "f(n1, n2, s2, t1)"

# check the scenarios and time steps are in s, t order
@test get(f, ("n1", "n2", 5, 3), 0.0) == 0.0

# check only and exactly existing flows have variables
@test issetequal( Set([(f[1], f[2]) for f in keys(f)]) , Set(get_flows(structure, names = true)))

# Test lower bound
@test all(lower_bound(f[flow.source, flow.sink, sce, t]) == 0.0 for flow in get_flows(structure), sce in S, t in T )




@info "Testing state variables"
s = state_variables(model, structure)

@test !isempty(s)

# check all storage nodes (2) have a variable
@test length(s) == 2*3*5

@test isa(s["n3", 3, 5], VariableRef)
@test string(s["n4", 2, 1]) == "s(n4, s2, t1)"

# check the scenarios and time steps are in s, t order
@test get(s, ("n3", 5, 3), 0.0) == 0.0

# check only and exactly existing storage nodes have variables
@test issetequal( Set([n[1] for n in keys(s)]) , Set(["n3", "n4"]))

# Test lower and upper bound
@test all(upper_bound(s[n.name, sce, t]) == n.state_max for n in [n3, n4], sce in S, t in T )
@test all(lower_bound(s[n.name, sce, t]) == 0.0 for n in [n3, n4], sce in S, t in T )




@info "Testing shortage and surplus variables"
shortage, surplus = shortage_surplus_variables(model, structure)

@test !isempty(shortage)
@test !isempty(surplus)
# check all storage and energy nodes (2+2) have a variable
@test length(surplus) == length(shortage)
@test length(surplus) == (2+2)*3*5

@test isa(shortage["n1", 3, 5], VariableRef)
@test isa(surplus["n1", 3, 5], VariableRef)

@test string(shortage["n2", 2, 1]) == "shortage(n2, s2, t1)"
@test string(surplus["n2", 2, 1]) == "surplus(n2, s2, t1)"

# check the scenarios and time steps are in s, t order
@test get(shortage, ("n1", 5, 3), 0.0) == 0.0
@test get(surplus, ("n1", 5, 3), 0.0) == 0.0

# check only and exactly existing energy and storage nodes have variables
@test issetequal( Set([n[1] for n in keys(shortage)]) , Set(["n1", "n2", "n3", "n4"]))
@test issetequal( Set([n[1] for n in keys(surplus)]) , Set(["n1", "n2", "n3", "n4"]))

# Test lower bound
@test all(lower_bound(shortage[n.name, sce, t]) == 0.0 for n in [n3, n4], sce in S, t in T )
@test all(lower_bound(surplus[n.name, sce, t]) == 0.0 for n in [n3, n4], sce in S, t in T )




@info "Testing start, stop and online variables"
start, stop, online = start_stop_online_variables(model, structure)

@test !isempty(start)
@test !isempty(stop)
@test !isempty(online)

@test length(start) == length(stop)
@test length(start) == length(online)
@test length(start) == 2*3*5

@test isa(start["p5", 3, 5], VariableRef)
@test isa(stop["p6", 3, 5], VariableRef)
@test isa(online["p5", 3, 5], VariableRef)

@test string(start["p6", 2, 1]) == "start(p6, s2, t1)"
@test string(stop["p5", 2, 1]) == "stop(p5, s2, t1)"
@test string(online["p6", 2, 1]) == "online(p6, s2, t1)"

# check the scenarios and time steps are in s, t order
@test get(start, ("p5", 5, 3), 0.0) == 0.0
@test get(stop, ("p5", 5, 3), 0.0) == 0.0
@test get(online, ("p5", 5, 3), 0.0) == 0.0

# check only and exactly existing online processes have variables
@test issetequal( Set([p[1] for p in keys(start)]) , Set(["p5", "p6"]))
@test issetequal( Set([p[1] for p in keys(stop)]) , Set(["p5", "p6"]))
@test issetequal( Set([p[1] for p in keys(online)]) , Set(["p5", "p6"]))

# Test lower bound
@test all(is_binary(start[p.name, sce, t]) for p in [p5, p6], sce in S, t in T )
@test all(is_binary(stop[p.name, sce, t]) for p in [p5, p6], sce in S, t in T )
@test all(is_binary(online[p.name, sce, t]) for p in [p5, p6], sce in S, t in T )