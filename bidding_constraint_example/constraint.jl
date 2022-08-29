using JuMP
using HouseCompanyEnergyModel 

# -- Energy market bidding constraints --
function market_bidding_constraints(model::Model, structure::ModelStructure,
    flow_variables::Dict{FlowTuple, VariableRef})

    # Dictionary for constraints, to be returned from function
    # the index is (market node name, scenario1, scenario2, time step)
    bidding_constraints = Dict{Tuple{String, Int, Int, Int}, ConstraintRef}()

    # Generate constraints for each market node, in each scenario and time step
    for m in structure.market_nodes, s in structure.S, t in structure.T

        # Get flow capturing energy sold and bought from market m
        # note: each market is connected to exactly one node by one input and one output flow
        sold = filter(f -> f.sink == m.name, structure.market_flows)[1]
        bought = filter(f -> f.source == m.name, structure.market_flows)[1]

        for s2 in structure.S 
            if m.price[s][t] < m.price[s2][t] && !(s == s2)
                
                c_ineq = @constraint(model, flow_variables[sold.source, sold.sink, s, t] - flow_variables[bought.source, bought.sink, s, t]
                                    ≤ flow_variables[sold.source, sold.sink, s2, t] - flow_variables[bought.source, bought.sink, s2, t])

                bidding_constraints[m.name, s, s2, t] = c_ineq
            end

            if m.price[s][t] == m.price[s2][t] && s < s2
                
                c_eq = @constraint(model, flow_variables[sold.source, sold.sink, s, t] - flow_variables[bought.source, bought.sink, s, t]
                                    == flow_variables[sold.source, sold.sink, s2, t] - flow_variables[bought.source, bought.sink, s2, t])

                bidding_constraints[m.name, s, s2, t] = c_eq
            end
        end
        
    end

    bidding_constraints
end