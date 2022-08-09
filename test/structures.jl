
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

# Plain node 1
@test isa(plain_node("n1", time_series, S, T), AbstractNode)
@test isa(plain_node("n1", time_series, S, T), PlainNode)
@test isa(PlainNode("n1", not_time_series), PlainNode)
@test_throws DomainError plain_node("n1", not_time_series, S , T)

# Storage node 2
@test isa(StorageNode("n2", 1.0, 1.0, 1.0, 0.1, not_time_series, 0.3), StorageNode)
@test isa(storage_node("n2", 1.0, 1.0, 1.0, 0.1, time_series, S, T, 0.3), AbstractNode)
@test isa(storage_node("n2", 1.0, 1.0, 1.0, 0.1, time_series, S, T, 0.3), StorageNode)
@test_throws DomainError storage_node("n2", 1.0, 1.0, 1.0, 0.1, not_time_series, S , T, 0.3)

# Commodity node 3
@test isa(CommodityNode("n3", not_time_series), CommodityNode)
@test isa(commodity_node("n3", time_series, S, T), AbstractNode)
@test isa(commodity_node("n3", time_series, S, T), CommodityNode)
@test_throws DomainError commodity_node("n3", not_time_series, S , T)

# Market node 4
@test isa(MarketNode("n4", not_time_series), MarketNode)
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

# Plain process 1
@test isa(PlainUnitProcess("p1", not_time_series), PlainUnitProcess)
@test isa(PlainUnitProcess("p1", efficiency), PlainUnitProcess)
@test isa(plain_unit_process("p1", efficiency, S, T), AbstractProcess)
@test isa(plain_unit_process("p1", efficiency, S, T), PlainUnitProcess)
@test_throws DomainError plain_unit_process("p1", not_time_series, S , T)
@test_throws DomainError plain_unit_process("p1", not_efficiency, S , T)

# CF process 2
@test isa(CFUnitProcess("p2", not_time_series), CFUnitProcess)
@test isa(CFUnitProcess("p2", cf), CFUnitProcess)
@test isa(cf_unit_process("p2", cf, S, T), AbstractProcess)
@test isa(cf_unit_process("p2", cf, S, T), CFUnitProcess)
@test_throws DomainError cf_unit_process("p2", not_time_series, S , T)
@test_throws DomainError cf_unit_process("p2", not_cf, S , T)

# Online process 3
@test isa(OnlineUnitProcess("p3", not_time_series, 0.1, 1, 1, 1.1, 2), OnlineUnitProcess)
@test isa(OnlineUnitProcess("p3", efficiency, 0.1, 1, 1, 1.1, 1), OnlineUnitProcess)
@test isa(online_unit_process("p3", efficiency, S, T, 0.1, 1, 1, 1.1, 1), OnlineUnitProcess)
@test isa(online_unit_process("p3", efficiency, S, T, 0.1, 1, 1, 1.1, 0), AbstractProcess)
@test_throws DomainError online_unit_process("p3", not_time_series, S, T, 0.1, 1, 1, 1.1, 1)
@test_throws DomainError online_unit_process("p3", not_efficiency, S, T, 0.1, 1, 1, 1.1, 1)
@test_throws DomainError online_unit_process("p3", efficiency, S, T, 0.1, 1, 1, 1.1, 2)
@test_throws DomainError online_unit_process("p3", efficiency, S, T, 2.0, 1, 1, 1.1, 1)




@info "Testing flows"
# Process Flow
@test isa(ProcessFlow("n1", "p1", 3.0, 1.0, 0.1), AbstractFlow)
@test isa(process_flow("n1", "p1", 3.0, 1.0, 0.1), ProcessFlow)
@test_throws DomainError process_flow("p1", "p1", 3.0, 1.0, 0.1)
@test_throws DomainError process_flow("n1", "p1", -1.0, 1.0, 0.1)
# test incorrect ramp rate value
@test_throws DomainError process_flow("n1", "p1", 3.0, 1.0, 2.0)  

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
n1 = plain_node("n1", time_series, S, T)
n2 = plain_node("n2", time_series, S, T)
n3 = storage_node("n3", 1.0, 1.0, 1.0, 0.1, time_series, S, T, 0.3)
n4 = storage_node("n4", 1.0, 1.0, 1.0, 0.1, time_series, S, T, 0.4)
n5 = commodity_node("n5", time_series, S, T)
n6 = commodity_node("n6", time_series, S, T)
n7 = market_node("n7", time_series, S, T)
n8 = market_node("n8", time_series, S, T)

# Adding nodes manually and get_names function works
structure.plain_nodes = [n1]
structure.storage_nodes = [n3]
structure.commodity_nodes = [n5]
structure.market_nodes = [n7]
@test get_names(structure, nodes=true) == ["n1","n3","n5","n7"]
@test get_names(structure, nodes=true, processes=true) == ["n1","n3","n5","n7"]

# Adding wrong types of nodes does not work
@test_throws MethodError structure.plain_nodes = [n1, n2, n3]
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
p1 = plain_unit_process("p1", efficiency, S, T)
p2 = plain_unit_process("p2", efficiency, S, T)
p3 = cf_unit_process("p3", cf, S, T)
p4 = cf_unit_process("p4", cf, S, T)
p5 = online_unit_process("p5", efficiency, S, T, 0.1, 1, 1, 1.1, 0)
p6 = online_unit_process("p6", efficiency, S, T, 0.1, 1, 1, 1.1, 0)
pn1 = plain_unit_process("n1", efficiency, S, T)

# Adding processes manually and get_names function works
structure.plain_processes = [p1]
structure.cf_processes = [p3]
structure.online_processes = [p5]
@test get_names(structure, processes=true) == ["p1","p3","p5"]
@test get_names(structure, nodes=true, processes=true) == ["n1","n2","n3","n4","n5","n6","n7","n8", "p1","p3","p5"]
@test get_names(structure, nodes=true) == ["n1","n2","n3","n4","n5","n6","n7","n8"]

# Adding wrong types of processes does not work
@test_throws MethodError structure.plain_nodes = [p1, p3]
@test_throws MethodError structure.storage_nodes = [p3, p5]
@test_throws MethodError structure.commodity_nodes = [p5, p2]

# add_nodes function works
add_processes!(structure, [p2])
add_processes!(structure, [p4, p6])

# add_processes does not alllow duplicate names to be added
@test_throws DomainError add_processes!(structure, [pn1])
@test_throws DomainError add_processes!(structure, [p2, p4, p6])


@test get_names(structure, nodes=true, processes=true) == ["n1","n2","n3","n4","n5","n6","n7","n8","p1","p2","p3","p4","p5","p6"]


@info "Testing adding flows"
# Flows for testing model logic specific constraints
# plain node - plain node
f1 = transfer_flow("n1", "n2")

# plain node - storage node
f2 = transfer_flow("n2", "n3")

# node/process - commodity node ERROR
fX3a = transfer_flow("n2", "n5")
fX3b = process_flow("p3", "n5", 3.0, 1.0, 1.0)

# commodity node - node
f4 = transfer_flow("n5", "n2")

# node - market node
f5a, f5b = market_flow("n1", "n7")
f5c, f5d = market_flow("n3", "n8")

# market node - market node ERROR
fX6a, fX6b = market_flow("n8", "n7")

# process - process ERROR
fX7 = process_flow("p1", "p6", 3.0, 1.0, 0.1)

# node - cf process ERROR
fX8a = process_flow("n3", "p3", 3.0, 1.0, 1.0)
fX8b = process_flow("n4", "p3", 4.0, 1.0, 1.0)

# commodity node - plain process
f9 = process_flow("n6", "p1", 4.0, 1.0, 0.1)

# cf process - plain node
f10 = process_flow("p3", "n2", 4.0, 1.0, 1.0)

# node - online process
f11a = process_flow("n5", "p5", 2.0, 1.0, 0.1)
# online process - storage node
f11b = process_flow("p6", "n3", 1.0, 1.0, 0.1)

# Flows for testing flow type specific constraints
# market node - plain process for all flow types ERROR
fX12a, fX12b = market_flow("n7", "p1")
fX12c = transfer_flow("n7", "p1")
fX12d = process_flow("n7", "p1", 8.0, 1.0, 0.1)

# plain process - plain node for all but ProcessFlow types ERROR
fX13a, fX13b = market_flow("n1", "p1")
fX13c = transfer_flow("n1", "p1")

# plain node - market node for all but MarketFlow types ERROR
fX14a = transfer_flow("n1", "n8")
fX14b = process_flow("n1", "n8",  8.0, 1.0, 0.1)


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

# add_flows! does not allow (node/process -> cf process) flows
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

# add storage node - plain process to include n4
f15 = process_flow("p2", "n4", 2.0, 1.0, 0.1)
add_flows!(structure, [f15])

# validate_network does not work when node p4 not connected
@test_throws DomainError validate_network(structure)

# add cf process - storage node to include p4
f16 = process_flow("p4", "n4", 2.0, 1.0, 1.0)
add_flows!(structure, [f16])

# validate_network works
@test validate_network(structure)

# check all 11 non-erroneous flows were added
@test length(get_flows(structure)) == 13

