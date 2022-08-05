using JuMP

function declare_objective(model::Model, structure::ModelStructure,
    flow_variables::Dict{FlowTuple, VariableRef},
    shortage_variables::Dict{NodeTuple, VariableRef},
    surplus_variables::Dict{NodeTuple, VariableRef})


    # Time steps and scenarios for code brevity in expression generation
    T = structure.T
    S = structure.S
    flows = get_flows(structure)

    # Scenario probabilities for code brevity in expression generation
    π = structure.scenario_probabilities
    
    # -- Commodity costs --
    # Vector of commodity costs for each commodity node
    commodity_costs = Vector{AffExpr}()
    for n in structure.commodity_nodes
        output_flows = filter(f -> f.source == n.name, flows)

        exp = @expression(model, sum(π[s]
                                 * sum(n.cost[s][t] * flow_variables[f.source, f.sink, t, s] for f in output_flows, t in T)
                                 for s in S))

        push!(commodity_costs, exp)
    end
    # Total costs of commodities accross all commodity nodes
    commodities = @expression(model, sum(commodity_costs))

    # -- Market costs --
    # Vector of market costs for each market node
    market_buying = Vector{AffExpr}()
    for n in structure.market_nodes
        bought_energy = filter(f -> f.source == n.name, flows)

        exp = @expression(model, sum(π[s]
                                 * sum(n.price[s][t] * flow_variables[f.source, f.sink, t, s] for f in bought_energy, t in T)
                                 for s in S))

        push!(market_buying, exp)
    end
    # Total costs of commodities accross all commodity nodes
    market_costs = @expression(model, sum(market_buying)) 
    
    @expression(model, commodities + market_costs)

end