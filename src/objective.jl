using JuMP


"""
    function declare_objective(model::Model, structure::ModelStructure,
        flow_variables::Dict{FlowTuple, VariableRef},
        shortage_variables::Dict{NodeTuple, VariableRef},
        surplus_variables::Dict{NodeTuple, VariableRef},
        penalty::Float64,
        start_variables::Dict{ProcessTuple, VariableRef} = Dict{ProcessTuple, VariableRef}())

Add expected cost minimising objective function to JuMP model.
"""
function declare_objective(model::Model, structure::ModelStructure,
    flow_variables::Dict{FlowTuple, VariableRef},
    shortage_variables::Dict{NodeTuple, VariableRef},
    surplus_variables::Dict{NodeTuple, VariableRef},
    penalty::Float64,
    start_variables::Dict{ProcessTuple, VariableRef} = Dict{ProcessTuple, VariableRef}())


    # Time steps and scenarios for code brevity in expression generation
    T = structure.T
    S = structure.S
    flows = get_flows(structure)

    # Scenario probabilities for code brevity in expression generation
    π = structure.scenario_probabilities
    


    # -- Commodity costs --
    # Vector of commodity costs for each commodity node
    comm_node_costs = Vector{AffExpr}()
    for n in structure.commodity_nodes
        output_flows = filter(f -> f.source == n.name, flows)

        exp = @expression(model, sum(π[s]
                                 * sum(n.cost[s][t] * flow_variables[f.source, f.sink, s, t] for f in output_flows, t in T)
                                 for s in S))

        push!(comm_node_costs, exp)
    end
    # Total costs of commodities accross all commodity nodes
    commodity_costs = @expression(model, sum(comm_node_costs))



    # -- Market costs --
    # Vector of market costs for each market node
    market_buying = Vector{AffExpr}()
    for n in structure.market_nodes
        bought_energy = filter(f -> f.source == n.name, flows)

        exp = @expression(model, sum(π[s]
                                 * sum(n.price[s][t] * flow_variables[f.source, f.sink, s, t] for f in bought_energy, t in T)
                                 for s in S))

        push!(market_buying, exp)
    end
    # Total costs of commodities accross all commodity nodes
    market_costs = @expression(model, sum(market_buying)) 
    


    # -- Market profits --
    # Vector of market profits for each market node
    market_selling = Vector{AffExpr}()
    for n in structure.market_nodes
        sold_energy = filter(f -> f.sink == n.name, flows)

        exp = @expression(model, sum(π[s]
                                 * sum(n.price[s][t] * flow_variables[f.source, f.sink, s, t] for f in sold_energy, t in T)
                                 for s in S))

        push!(market_selling, exp)
    end
    market_profits = @expression(model, sum(market_selling))



    # -- VOM costs --
    vom_costs = @expression(model, sum(π[s] * f.VOM_cost * flow_variables[f. source, f.sink, s, t] 
                                    for f in structure.process_flows, t in T, s in S))


    # -- Start costs --
    start_costs = @expression(model, sum(π[s] *  p.start_cost * start_variables[p.name, s, t] 
                                    for p in structure.online_processes, t in T, s in S))


    # -- Penalty costs --
    balance_nodes = [structure.energy_nodes..., structure.storage_nodes...]
    penalty_cost = @expression(model, sum(π[s] * penalty * (shortage_variables[n.name, s, t] + surplus_variables[n.name, s, t])
                                    for n in balance_nodes, t in T, s in S))



    @objective(model, Min, commodity_costs + market_costs - market_profits + vom_costs + start_costs + penalty_cost)

end