using JuMP

# -- Storage constraints --

# Initial state constraint
function initial_state_constraints(model::Model, 
    state_variables::Dict{NodeTuple, VariableRef}, 
    structure::ModelStructure)

    # Dictionary of constraints, to be returned from function 
    constraints = Dict{NodeTuple, ConstraintRef}()

    # Generating initial state constraints
    for n in structure.storage_nodes, s in structure.S
        c = @constraint(model, state_variables[n.name, 1, s] == n.initial_state, base_name="initial_state_constraint[$(n.name), s$s]")

        constraints[n.name, 1, s] = c
    end

    constraints
end

# function initial_state_constraints(model::Model, 
#     state_variables::Dict{NodeTuple, VariableRef}, 
#     structure::ModelStructure)

#     # storage node names and scnearios
#     names = [n.name for n in structure.storage_nodes]
#     S = structure.S

#     # Dictionary name => initial_state for easy access in constraint generation
#     initial_states = Dict(map(n -> (n.name => n.initial_state), structure.storage_nodes))
    

#     @constraint(model, [n in names, s in S], state_variables[n, 1, s] == initial_states[n])

# end

# Charging and discharging storage constraint
function charging_discharging_constraints(model::Model, 
    state_variables::Dict{NodeTuple, VariableRef}, 
    structure::ModelStructure)

    # charging and discharging constraints only declared for time steps from 2nd to last
    T_tail = 2:length(structure.T)
    
    # Dictionaries of constraints, to be returned from function
    charging_constraints = Dict{NodeTuple, ConstraintRef}()
    discharging_constraints = Dict{NodeTuple, ConstraintRef}()

    # Declare charging and discharging constraints for each storage node, time step (2:end) and scenario
    for n in structure.storage_nodes, t in T_tail, s in structure.S
        charging = @constraint(model, n.in_flow_max ≥ state_variables[n.name,t,s] - (1-n.state_loss) * state_variables[n.name,t-1,s], base_name="charge_constraint[$(n.name), t$t, s$s]")
        charging_constraints[n.name, t, s] = charging

        discharging = @constraint(model, -n.out_flow_max ≤ state_variables[n.name,t,s] - (1-n.state_loss) * state_variables[n.name,t-1,s])
        discharging_constraints[n.name, t, s] = discharging
    end
    
    charging_constraints, discharging_constraints
end

# -- Energy flow through unit type processes upper and lower bound constraints --
function process_flow_bound_constraints(model::Model,
    flow_variables::Dict{FlowTuple, VariableRef},
    online_variables::Dict{ProcessTuple, VariableRef}, 
    structure::ModelStructure)

    # Names of different process types for easy access in constraint generation
    plain_processes = [p.name for p in structure.plain_processes]
    cf_processes = [p.name for p in structure.cf_processes]
    online_processes = [p.name for p in structure.online_processes]
    
    # Dictionary for constraints, to be returned from function
    flow_bound_constraints = Dict{FlowTuple, Vector{ConstraintRef}}()

    # Iterate through all process flows and create lower and upper bound constraints
    for f in structure.process_flows, t in structure.T, s in structure.S

        # Flow to or from a plain process
        if f.source in plain_processes || f.sink in plain_processes

            # note: lower bound 0 already constrained in variable creation, redeclared here for readability
            c = @constraint(model, 0 ≤ flow_variables[f.source, f.sink, t, s] ≤ f.capacity[s][t])
            flow_bound_constraints[f.source, f.sink, t, s] = [c]


        # Flow from a cf processes
        elseif f.source in cf_processes
            # Find CFUnitProcess structure of process in question
            p = filter(p -> p.name == f.source, structure.cf_processes)[1]

            # note: lower bound 0 already constrained in variable creation, redeclared here for readability
            c = @constraint(model, 0 ≤ flow_variables[f.source, f.sink, t, s] ≤ f.capacity[s][t] * p.cf[s][t])
            flow_bound_constraints[f.source, f.sink, t, s] = [c]


        # Flow to or from an online process
        elseif f.source in online_processes || f.sink in online_processes
            # Find OnlineUnitProcess structure of process in question (notice add_flows would not allow process-process connection so this is safe)
            p = filter(p -> p.name == f.source || p.name == f.sink, structure.online_processes)[1]

            lower_bound = @expression(model, p.min_load * f.capacity[s][t] * online_variables[p.name, t, s])
            upper_bound = @expression(model, f.capacity[s][t] * online_variables[p.name, t, s])

            c_lb = @constraint(model, lower_bound ≤ flow_variables[f.source, f.sink, t, s])
            c_ub = @constraint(model, flow_variables[f.source, f.sink, t, s] ≤ upper_bound)
            flow_bound_constraints[f.source, f.sink, t, s] = [c_lb, c_ub]

        end
    end

    flow_bound_constraints

end


# -- Ramp rate of plain and online processes constraints --
function process_ramp_rate_constraints(model::Model, 
    flow_variables::Dict{FlowTuple, VariableRef},
    start_variables::Dict{ProcessTuple, VariableRef},
    stop_variables::Dict{ProcessTuple, VariableRef}, 
    structure::ModelStructure)

    # Names of different process types for easy access in constraint generation
    plain_processes = [p.name for p in structure.plain_processes]
    online_processes = [p.name for p in structure.online_processes]

    # ramping constraints only declared for time steps from 2nd to last
    T_tail = 2:length(structure.T)
    
    # Dictionary for constraints, to be returned from function
    ramp_rate_constraints = Dict{FlowTuple, Vector{ConstraintRef}}()

    # Iterate through all process flows and create lower and upper bound constraints
    for f in structure.process_flows, t in T_tail, s in structure.S
    
        # Flow to or from a plain process
        if f.source in plain_processes || f.sink in plain_processes
            
            c = @constraint(model, -f.ramp_rate * f.capacity[s][t] 
                            ≤ flow_variables[f.source, f.sink, t, s] - flow_variables[f.source, f.sink, t-1, s] 
                            ≤ f.ramp_rate * f.capacity[s][t])
            ramp_rate_constraints[f.source, f.sink, t, s] = [c]


        # Flow to or from an online process
        elseif f.source in online_processes || f.sink in online_processes
            
            # Find OnlineUnitProcess structure of process in question (notice add_flows would not allow process-process connection so this is safe)
            p = filter(p -> p.name == f.source || p.name == f.sink, structure.online_processes)[1]

            lower_bound = @expression(model, - f.ramp_rate * f.capacity[s][t] 
                                - max(0, p.min_load * f.capacity[s][t] - f.ramp_rate) * stop_variables[p.name, t, s])

            upper_bound = @expression(model, f.ramp_rate * f.capacity[s][t] 
                                + max(0, p.min_load * f.capacity[s][t] - f.ramp_rate) * start_variables[p.name, t, s])

            c_lb = @constraint(model, lower_bound ≤ flow_variables[f.source, f.sink, t, s] - flow_variables[f.source, f.sink, t-1, s])
            c_ub = @constraint(model, flow_variables[f.source, f.sink, t, s] - flow_variables[f.source, f.sink, t-1, s] ≤ upper_bound)
            ramp_rate_constraints[f.source, f.sink, t, s] = [c_lb, c_ub]

        end # note: cf processes cannot be ramped -> no ramp constraints
    end

    ramp_rate_constraints
end

# -- Process efficiency constraints --
function process_efficiency_constraints(model::Model, 
    flow_variables::Dict{FlowTuple, VariableRef},
    structure::ModelStructure)

    # Efficiency constraints apply to plain and online processes
    processes = [structure.plain_processes..., structure.online_processes...]

    # Dictionary for constraints, to be returned from function
    efficiency_constraints = Dict{ProcessTuple, ConstraintRef}()

    for p in processes, t in structure.T, s in structure.S

        output_flows = filter(f -> f.source == p.name, structure.process_flows)
        output_flows = map(f -> (f.source, f.sink), output_flows)

        input_flows = filter(f -> f.sink == p.name, structure.process_flows)
        input_flows = map(f -> (f.source, f.sink), input_flows)

        c = @constraint(model, sum(flow_variables[i, j, t, s] for (i,j) in output_flows) 
                            == p.efficiency[s][t] * sum(flow_variables[i, j, t, s] for (i,j) in input_flows))

        efficiency_constraints[p.name, t, s] = c
    end

    efficiency_constraints

end

# -- Online/offline functionality constraints --
function online_functionality_constraints(model::Model, 
    start_variables::Dict{NodeTuple, VariableRef},
    stop_variables::Dict{NodeTuple, VariableRef},
    online_variables::Dict{NodeTuple, VariableRef},
    structure::ModelStructure)

    # Find last time step for ease in constraint generation
    t_max = length(structure.T)

    # Dictionaries of constraints, to be returned from function
    on_off_constraints = Dict{ProcessTuple, ConstraintRef}()
    min_online_constraints = Dict{ProcessTuple, Vector{ConstraintRef}}()
    min_offline_constraints = Dict{ProcessTuple, Vector{ConstraintRef}}()

    for p in structure.online_processes, t in structure.T, s in structure.S
        
        # Set initial status constraint 
        if t == 1 # set initial status
            c = @constraint(model, online_variables[p.name,t,s] == p.initial_status) 
            on_off_constraints[p.name,t,s] = c
        
        # Set on/off functionality constraints for later time steps
        else
            c = @constraint(model, online_variables[p.name,t,s] 
                            == online_variables[p.name,t-1,s] + start_variables[p.name,t,s] - stop_variables[p.name,t,s])
            
            on_off_constraints[p.name,t,s] = c
        end

        # Set min online time constraints
        for t2 in t:min(t_max, t+p.min_online)
            c_min_online = @constraint(model, online_variables[p.name, t2, s] ≥ start_variables[p.name,t,s])

            # Insert constraints by first initialising key [p.name, t, s] and then pushing to this vector
            if t2 == t
                min_online_constraints[p.name,t,s] = [c_min_online]
            else
                push!(min_online_constraints[p.name,t,s], c_min_online)
            end
        end

        # Set min offline time constraints
        for t3 in t:min(t_max, t+p.min_offline)
            c_min_offline = @constraint(model, online_variables[p.name, t3, s] ≤ 1 - stop_variables[p.name,t,s])

            # Insert constraints by first initialising key [p.name, t, s] and then pushing to this vector
            if t3 == t
                min_offline_constraints[p.name,t,s] = [c_min_offline]
            else
                push!(min_offline_constraints[p.name,t,s], c_min_offline)
            end
        end

    end

    on_off_constraints, min_online_constraints, min_offline_constraints
end

# -- Energy market bidding constraints --
function market_bidding_constraints(model::Model, 
    flow_variables::Dict{FlowTuple, VariableRef},
    structure::ModelStructure)

    # Dictionary for constraints, to be returned from function
    bidding_constraints = Dict{NodeTuple, Vector{ConstraintRef}}()

    # Generate constraints for each market node, in each scenario and time step
    for m in structure.market_nodes, s in structure.S, t in structure.T

        # Get flow capturing energy sold and bought from market m
        # note: each market is connected to exactly one node by one input and one output flow
        sold = filter(f -> f.sink == m.name, structure.market_flows)[1]
        bought = filter(f -> f.source == m.name, structure.market_flows)[1]

        # Initialise vector of constraints
        bidding_constraints[m.name, t, s] = []

        for s2 in structure.S 
            if m.price[s][t] ≤ m.price[s2][t] && !(s == s2)
                
                c_ineq = @constraint(model, flow_variables[sold.source, sold.sink, t, s] - flow_variables[bought.source, bought.sink, t, s]
                                    ≤ flow_variables[sold.source, sold.sink, t, s2] - flow_variables[bought.source, bought.sink, t, s2])

                push!(bidding_constraints[m.name, t, s], c_ineq)
            end

            if m.price[s][t] == m.price[s2][t] && !(s == s2)
                
                c_eq = @constraint(model, flow_variables[sold.source, sold.sink, t, s] - flow_variables[bought.source, bought.sink, t, s]
                                    == flow_variables[sold.source, sold.sink, t, s2] - flow_variables[bought.source, bought.sink, t, s2])

                push!(bidding_constraints[m.name, t, s], c_eq)
            end
        end
        
        # If no constraints were generated for this market, scenario and time step, delete the entry
        if isempty(bidding_constraints[m.name, t, s])
            delete!(bidding_constraints, (m.name, t, s))
        end
    end

    bidding_constraints
end