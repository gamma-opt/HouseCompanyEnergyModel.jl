
@info "Structures:"
@info "Testing time steps, scenarios and time series"
T = time_steps(5)
S = scenarios(3)
time_series = [[1,2,3, 4, 5], [1.0,2.0,3.0, 4, 5], [4, 5.5, 6.6, 1, 1]]
@test isa(T, TimeSteps)
@test isa(S, Scenarios)

# works
@test isa(time_series, TimeSeries)
@test validate_time_series(time_series, S, T)

# does not work
@test_throws DomainError validate_time_series([[1,2,3, 4], [1.0,2.0,3.0, 4, 5], [4, 5.5, 6.6, 1, 1]], S, T)
@test_throws DomainError validate_time_series([[1.0,2,3, 4, 5]], S, T)




@info "Testing nodes"
not_time_series = [[1,2,3, 4, 5], [1.0,2.0,3.0, 4, 5]]

# Energy node 1
@test isa(energy_node("n1", time_series, S, T), AbstractNode)
@test isa(energy_node("n1", time_series, S, T), EnergyNode)
@test_throws DomainError energy_node("n1", not_time_series, S , T)

# Storage node 2
@test isa(storage_node("n2", 1.0, 1.0, 1.0, 0.1, time_series, S, T, 0.3), AbstractNode)
@test isa(storage_node("n2", 1.0, 1.0, 1.0, 0.1, time_series, S, T, 0.3), StorageNode)
@test_throws DomainError storage_node("n2", 1.0, 1.0, 1.0, 0.1, not_time_series, S , T, 0.3)

# Commodity node 3
@test isa(commodity_node("n3", time_series, S, T), AbstractNode)
@test isa(commodity_node("n3", time_series, S, T), CommodityNode)
@test_throws DomainError commodity_node("n3", not_time_series, S , T)

# Market node 4
@test isa(market_node("n4", time_series, S, T), AbstractNode)
@test isa(market_node("n4", time_series, S, T), MarketNode)
@test_throws DomainError market_node("n4", not_time_series, S , T)




@info "Testing processes"
# time series and values [0,1]
efficiency = [[0.1, 0.1, 0.1, 0.1, 0.1], [0.1, 0.1, 0.1, 0.1, 0.1], [0.1, 0.1, 0.1, 0.1, 0.1]]
# time series and values [0,1]
cf = [[0.1, 0.1, 0.1, 0.1, 0.1], [0.1, 0.1, 0.1, 0.1, 0.1], [0.1, 0.1, 0.1, 0.1, 0.1]]
# time series and values not [0,1]
not_efficiency = [[1,2,3, 4, 5], [1.0,2.0,3.0, 4, 5], [4, 5.5, 6.6, 1, 1]]
# time series and values not [0,1]
not_cf = [[1,2,3, 4, 5], [1.0,2.0,3.0, 4, 5], [4, 5.5, 6.6, 1, 1]]

# Flexible process 1
@test isa(FlexibleProcess("p1", efficiency), FlexibleProcess)
@test isa(flexible_process("p1", efficiency, S, T), AbstractProcess)
@test isa(flexible_process("p1", efficiency, S, T), FlexibleProcess)
@test_throws DomainError flexible_process("p1", not_time_series, S , T)
@test_throws DomainError flexible_process("p1", not_efficiency, S , T)

# VRE process 2
@test isa(VREProcess("p2", cf), VREProcess)
@test isa(vre_process("p2", cf, S, T), AbstractProcess)
@test isa(vre_process("p2", cf, S, T), VREProcess)
@test_throws DomainError vre_process("p2", not_time_series, S , T)
@test_throws DomainError vre_process("p2", not_cf, S , T)

# Online process 3
@test isa(OnlineProcess("p3", efficiency, 0.1, 1, 1, 1.1, 1), OnlineProcess)
@test isa(online_process("p3", efficiency, S, T, 0.1, 1, 1, 1.1, 1), OnlineProcess)
@test isa(online_process("p3", efficiency, S, T, 0.1, 1, 1, 1.1, 0), AbstractProcess)
@test_throws DomainError online_process("p3", not_time_series, S, T, 0.1, 1, 1, 1.1, 1)
@test_throws DomainError online_process("p3", not_efficiency, S, T, 0.1, 1, 1, 1.1, 1)
@test_throws DomainError online_process("p3", efficiency, S, T, 0.1, 1, 1, 1.1, 2)
@test_throws DomainError online_process("p3", efficiency, S, T, 2.0, 1, 1, 1.1, 1)
@test_throws MethodError online_process("p3", efficiency, S, T, 2, 1.1, 1, 3, 1)
@test_throws MethodError online_process("p3", efficiency, S, T, 2, 1, 1.2, 3, 1)




@info "Testing flows"
# Process Flow
@test isa(ProcessFlow("n1", "p1", 3.0, 1.0, 0.1), AbstractFlow)
@test isa(process_flow("n1", "p1", 3, 1, 0), ProcessFlow)
@test_throws DomainError process_flow("p1", "p1", 3.0, 1.0, 0.1)
# test incorrect (negative) capacity value
@test_throws DomainError process_flow("n1", "p1", -1.0, 1.0, 0.1)
# test incorrect ramp rate value
@test_throws DomainError process_flow("n1", "p1", 3.0, 1, 2.0)  

# Transfer Flow
@test isa(TransferFlow("n1", "n2"), AbstractFlow)
@test isa(transfer_flow("n1", "n2"), TransferFlow)
@test_throws DomainError transfer_flow("n1", "n1")

# Market Flow
@test isa(MarketFlow("n1", "n2"), AbstractFlow)
@test isa(market_flow("n1", "n2")[1], MarketFlow)
@test isa(market_flow("n1", "n2")[2], MarketFlow)
@test_throws DomainError market_flow("n1", "n1")



@info "Testing model structure"
@test_throws DomainError ModelStructure(scenarios(3), time_steps(5), [0.5, 0.5, 0.5])
structure = ModelStructure(scenarios(3), time_steps(5), [0.4, 0.3, 0.3])
@test isa(structure, ModelStructure)



@info "Testing adding nodes"
# example nodes, two of each type
n1 = energy_node("n1", time_series, S, T)
n2 = energy_node("n2", time_series, S, T)
n3 = storage_node("n3", 1.0, 1.0, 1.0, 0.1, time_series, S, T, 0.3)
n4 = storage_node("n4", 1.0, 1.0, 1.0, 0.1, time_series, S, T, 0.4)
n5 = commodity_node("n5", time_series, S, T)
n6 = commodity_node("n6", time_series, S, T)
n7 = market_node("n7", time_series, S, T)
n8 = market_node("n8", time_series, S, T)

# Adding nodes manually and get_names function works
structure.energy_nodes = [n1]
structure.storage_nodes = [n3]
structure.commodity_nodes = [n5]
structure.market_nodes = [n7]
@test get_names(structure, nodes=true) == ["n1","n3","n5","n7"]
@test get_names(structure, nodes=true, processes=true) == ["n1","n3","n5","n7"]

# Adding wrong types of nodes does not work
@test_throws MethodError structure.energy_nodes = [n1, n2, n3]
@test_throws MethodError structure.storage_nodes = [n3, n4, n5]
@test_throws MethodError structure.commodity_nodes = [n5, n6, n7]
@test_throws MethodError structure.market_nodes = [n1, n7, n2]

# add_nodes function works
add_nodes!(structure, [n2])
add_nodes!(structure, [n4, n6, n8])

# add_nodes does not allow duplicates to be added
@test_throws DomainError add_nodes!(structure, [n2, n4, n6, n8])



@info "Testing adding processes"
# example processes, two of each type
p1 = flexible_process("p1", efficiency, cf, S, T, 0.2)
p2 = flexible_process("p2", efficiency, cf, S, T, 0.2)
p3 = vre_process("p3", cf, S, T)
p4 = vre_process("p4", cf, S, T)
p5 = online_process("p5", efficiency, cf, S, T, 0.1, 1, 1, 0.2, 1.1, 0)
p6 = online_process("p6", efficiency, cf, S, T, 0.1, 1, 1, 0.2, 1.1, 0)
pn1 = flexible_process("n1", efficiency, cf, S, T, 0.2)

# Adding processes manually and get_names function works
structure.flexible_processes = [p1]
structure.vre_processes = [p3]
structure.online_processes = [p5]
@test get_names(structure, processes=true) == ["p1","p3","p5"]
@test get_names(structure, nodes=true, processes=true) == ["n1","n2","n3","n4","n5","n6","n7","n8", "p1","p3","p5"]
@test get_names(structure, nodes=true) == ["n1","n2","n3","n4","n5","n6","n7","n8"]

# Adding wrong types of processes does not work
@test_throws MethodError structure.flexible_processes = [p1, p3]
@test_throws MethodError structure.vre_processes = [p3, p5]
@test_throws MethodError structure.online_processes = [p5, p2]

# add_nodes function works
add_processes!(structure, [p2])
add_processes!(structure, [p4, p6])

# add_processes does not alllow duplicate names to be added
@test_throws DomainError add_processes!(structure, [pn1])
@test_throws DomainError add_processes!(structure, [p2, p4, p6])


@test get_names(structure, nodes=true, processes=true) == ["n1","n2","n3","n4","n5","n6","n7","n8","p1","p2","p3","p4","p5","p6"]


@info "Testing adding flows"
# Flows for testing model logic specific constraints
# energy node - energy node
f1 = transfer_flow("n1", "n2")

# energy node - storage node
f2 = transfer_flow("n2", "n3")

# node/process - commodity node ERROR
fX3a = transfer_flow("n2", "n5")
fX3b = process_flow("p3", "n5", 3.0, 1.0)

# commodity node - node
f4 = transfer_flow("n5", "n2")

# node - market node
f5a, f5b = market_flow("n1", "n7")
f5c, f5d = market_flow("n3", "n8")

# market node - market node ERROR
fX6a, fX6b = market_flow("n8", "n7")

# process - process ERROR
fX7 = process_flow("p1", "p6", 3.0, 1.0)

# node - vre process ERROR
fX8a = process_flow("n3", "p3", 3.0, 1.0)
fX8b = process_flow("n4", "p3", 4.0, 1.0)

# commodity node - flexible process
f9 = process_flow("n6", "p1", 4.0, 1.0)

# vre process - energy node
f10 = process_flow("p3", "n2", 4.0, 1.0)

# node - online process
f11a = process_flow("n5", "p5", 2.0, 1.0)
# online process - storage node
f11b = process_flow("p6", "n3", 1.0, 1.0)

# Flows for testing flow type specific constraints
# market node - flexible process for all flow types ERROR
fX12a, fX12b = market_flow("n7", "p1")
fX12c = transfer_flow("n7", "p1")
fX12d = process_flow("n7", "p1", 8.0, 1.0)

# energy node - flexible process for all but ProcessFlow types ERROR
fX13a, fX13b = market_flow("n1", "p1")
fX13c = transfer_flow("n1", "p1")

# energy node - market node for all but MarketFlow types ERROR
fX14a = transfer_flow("n1", "n8")
fX14b = process_flow("n1", "n8",  8.0, 1.0)


# add_flows! works for (node -> node) flows
add_flows!(structure, [f1])
add_flows!(structure, [f2])
@test structure.transfer_flows == [f1, f2]

# get_flows works
@test get_flows(structure) == [f1, f2]
@test get_flows(structure, names=true) == [("n1", "n2"), ("n2", "n3")]

# add_flows! does not allow (node/process -> commodity node) flows
@test_throws DomainError add_flows!(structure, [fX3a])
@test_throws DomainError add_flows!(structure, [fX3b])

# add_flows! does not add set of flows if there is an erroneous flow 
@test_throws DomainError add_flows!(structure, [fX3a, f4])
@test structure.transfer_flows == [f1, f2]
@test structure.market_flows == []

# add_flows! works for (node -> node) flows
add_flows!(structure, [f4, f5a, f5b, f5c, f5d])
@test structure.transfer_flows == [f1, f2, f4]
@test structure.market_flows == [f5a, f5b, f5c, f5d]

# add_flows! does not allow (market node - market node) flows
@test_throws DomainError add_flows!(structure, [fX6a])

# add_flows! does not allow (process - process) flows
@test_throws DomainError add_flows!(structure, [fX7])

# add_flows! does not allow (node/process -> vre process) flows
@test_throws DomainError add_flows!(structure, [fX8a])
@test_throws DomainError add_flows!(structure, [fX8b])

# add_flows! works for (node -> process) and (process -> node) flows
add_flows!(structure, [f9, f10, f11a, f11b])
@test structure.process_flows == [f9, f10, f11a, f11b]

# add_flows! does not allow flows violating flow type constraints
@test_throws DomainError add_flows!(structure, [fX12a])
@test_throws DomainError add_flows!(structure, [fX12b])
@test_throws DomainError add_flows!(structure, [fX12c])
@test_throws DomainError add_flows!(structure, [fX12d])
@test_throws DomainError add_flows!(structure, [fX13a])
@test_throws DomainError add_flows!(structure, [fX13b])
@test_throws DomainError add_flows!(structure, [fX13c])
@test_throws DomainError add_flows!(structure, [fX14a])
@test_throws DomainError add_flows!(structure, [fX14b])


@info "Testing validate model structure"

# validate_network does not work when node n4 and p4 not connected
@test_throws DomainError validate_network(structure)

# add storage node - flexible process to include n4
f15 = process_flow("p2", "n4", 2.0, 1.0)
add_flows!(structure, [f15])

# validate_network does not work when node p4 not connected
@test_throws DomainError validate_network(structure)

# add vre process - storage node to include p4
f16 = process_flow("p4", "n4", 2.0, 1.0)
add_flows!(structure, [f16])

# validate_network works
@test validate_network(structure)

# check all 11 non-erroneous flows were added
@test length(get_flows(structure)) == 13

