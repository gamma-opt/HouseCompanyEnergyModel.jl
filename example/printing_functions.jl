using PrettyTables

function net_energy_from_market(structure::ModelStructure, flow_variables::Dict{FlowTuple, VariableRef})

    # Finding optimal buying and selling quantities
    for n in structure.market_nodes

        # Empty array for storing net energy sums
        net_energy = zeros(length(structure.S), length(structure.T))

        # Filtering flows to and from the market in question
        bought_energy = filter(f -> f.source == n.name, structure.market_flows)
        sold_energy = filter(f -> f.sink == n.name, structure.market_flows)
        
        for s in structure.S, t in structure.T
            # Sum optimal values of flows 
            bought_sum = sum(value(flow_variables[f.source, f.sink, s, t]) for f in bought_energy)
            sold_sum = sum(value(flow_variables[f.source, f.sink, s, t]) for f in sold_energy)

            # Calculate net energy = bought - sold
            net_energy[s, t] = bought_sum - sold_sum
        end
        

        println("\nMarket $(n.name)")
        println("Net energy = bought - sold")
        pretty_table(net_energy;
                    header = (["t$t" for t in structure.T]))

        println("Prices")
        print_time_series(structure, n.price)
                
    end

end


function PV_energy_generated(structure::ModelStructure, flow_variables::Dict{FlowTuple, VariableRef})

    # Finding optimal buying and selling quantities
    for p in structure.vre_processes

        # Empty array for storing net energy sums and prices
        energy = zeros(length(structure.S), length(structure.T))
        available_capacity = zeros(length(structure.S), length(structure.T))

        # Filtering flows from the PV process in question
        generation = filter(f -> f.source == p.name, structure.process_flows)
        
        for s in structure.S, t in structure.T
            # Sum optimal values of flows 
            generation_sum = sum(value(flow_variables[f.source, f.sink, s, t]) for f in generation)
            capacity = sum(f.capacity*p.cf[s][t] for f in generation)

            # Calculate net energy = bought - sold
            energy[s, t] = generation_sum
            available_capacity[s, t] = capacity
        end
        

        println("\nProcess $(p.name)")
        println("Energy generated")
        pretty_table(energy;
                    header = (["t$t" for t in structure.T]))

        println("Available capacity")
        pretty_table(available_capacity;
                    header = (["t$t" for t in structure.T]))
                
    end

end


function print_time_series(structure::ModelStructure, time_series::TimeSeries)

    data = zeros(length(structure.S), length(structure.T))

    for s in structure.S, t in structure.T
        data[s,t] = time_series[s][t]
    end

    pretty_table(data;
                    header = (["t$t" for t in structure.T]))
end



function objective_per_scenario(structure::ModelStructure,
    flow_variables::Dict{FlowTuple, VariableRef},
    shortage_variables::Dict{NodeTuple, VariableRef},
    surplus_variables::Dict{NodeTuple, VariableRef},
    penalty::Float64,
    start_variables::Dict{ProcessTuple, VariableRef} = Dict{ProcessTuple, VariableRef}())


    # Time steps and scenarios for code brevity in expression generation
    T = structure.T
    S = structure.S
    flows = get_flows(structure)
    

    costs = zeros(length(S))

    # -- Commodity costs --
    for n in structure.commodity_nodes
        output_flows = filter(f -> f.source == n.name, flows)

        for s in S
            costs[s] += sum(n.cost[s][t] * value(flow_variables[f.source, f.sink, s, t]) for f in output_flows, t in T)
        end
    end


    # -- Market costs --
    for n in structure.market_nodes
        bought_energy = filter(f -> f.source == n.name, flows)

        for s in S
            costs[s] += sum(n.price[s][t] * value(flow_variables[f.source, f.sink, s, t]) for f in bought_energy, t in T)
        end
    end
    #println("market costs: $costs")


    # -- Market profits --
    for n in structure.market_nodes
        sold_energy = filter(f -> f.sink == n.name, flows)
        
        for s in S
            costs[s] -= sum(n.price[s][t] * value(flow_variables[f.source, f.sink, s, t]) for f in sold_energy, t in T)
        end
    end
    #println("after market profits: $costs")

    # -- VOM costs --
    for s in S
        costs[s] += sum(f.VOM_cost * value(flow_variables[f. source, f.sink, s, t]) for f in structure.process_flows, t in T)
    end
    #println("after vom costs: $costs")

    # -- Start costs --
    if !isempty(start_variables)
        for s in S
            costs[s] += sum(p.start_cost * value(start_variables[p.name, s, t]) for p in structure.online_processes, t in T)
        end
    end

    # -- Penalty costs --
    balance_nodes = [structure.plain_nodes..., structure.storage_nodes...]
    for s in S
        costs[s] += sum(penalty * (value(shortage_variables[n.name, s, t]) + value(surplus_variables[n.name, s, t])) for n in balance_nodes, t in T)
    end


    costs

end