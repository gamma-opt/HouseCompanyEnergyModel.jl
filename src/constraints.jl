using JuMP

# -- Storage constraints --
"""
    function charging_discharging_constraints(model::Model, structure::ModelStructure,
        state_variables::Dict{NodeTuple, VariableRef})  

Add charging and discharging storage constraints to JuMP model.
"""
function charging_discharging_constraints(model::Model, structure::ModelStructure,
    state_variables::Dict{NodeTuple, VariableRef})
    
    # Dictionaries of constraints, to be returned from function
    charging_constraints = Dict{NodeTuple, ConstraintRef}()
    discharging_constraints = Dict{NodeTuple, ConstraintRef}()

    # Declare charging and discharging constraints for each storage node, time step and scenario
    for n in structure.storage_nodes, t in structure.T, s in structure.S

        # At first time step, the change in storage is calculated between state(t=1)-initial_state
        if t == 1
            charging = @constraint(model, n.in_flow_max ≥ state_variables[n.name, s, t] - (1-n.state_loss) * n.initial_state)
            charging_constraints[n.name, s, t] = charging

            discharging = @constraint(model, -n.out_flow_max ≤ state_variables[n.name, s, t] - (1-n.state_loss) * n.initial_state)
            discharging_constraints[n.name, s, t] = discharging
        
        # At other time steps, the change in storage is calculated between state(t)-state(t-1)
        else
            charging = @constraint(model, n.in_flow_max ≥ state_variables[n.name, s, t] - (1-n.state_loss) * state_variables[n.name, s, t-1])
            charging_constraints[n.name, s, t] = charging

            discharging = @constraint(model, -n.out_flow_max ≤ state_variables[n.name, s, t] - (1-n.state_loss) * state_variables[n.name, s, t-1])
            discharging_constraints[n.name, s, t] = discharging
        end
    end
    
    charging_constraints, discharging_constraints
end

# -- Energy balance constraints --
"""
    function energy_balance_constraints(model::Model, structure::ModelStructure, 
        flow_variables::Dict{FlowTuple, VariableRef},
        shortage_variables::Dict{NodeTuple, VariableRef},
        surplus_variables::Dict{NodeTuple, VariableRef},
        state_variables::Dict{NodeTuple, VariableRef} = Dict{NodeTuple, VariableRef}())  

Add energy balance constraints for energy and storage nodes to JuMP model.
"""
function energy_balance_constraints(model::Model, structure::ModelStructure, 
    flow_variables::Dict{FlowTuple, VariableRef},
    shortage_variables::Dict{NodeTuple, VariableRef},
    surplus_variables::Dict{NodeTuple, VariableRef},
    state_variables::Dict{NodeTuple, VariableRef} = Dict{NodeTuple, VariableRef}())

    # Get all flows from structure into one variable for ease of use
    flows = get_flows(structure)

    # Energy nodes and storage nodes are the only ones were balance is maintained (not in commodity or market nodes)
    balance_nodes = [structure.energy_nodes..., structure.storage_nodes...]

    # Dictionary of constraints, to be returned from function 
    balance_constraints = Dict{NodeTuple, ConstraintRef}()

    # Generate balance equation for storage nodes. Note: energy nodes don't have storage, thus LHS=0
    for n in balance_nodes, s in structure.S, t in structure.T

        output_flows = filter(f -> f.source == n.name, flows)
        output_flows = map(f -> (f.source, f.sink), output_flows)

        input_flows = filter(f -> f.sink == n.name, flows)
        input_flows = map(f -> (f.source, f.sink), input_flows)

        # Declare left hand side of constraint
        if isa(n, EnergyNode)
            # Energy nodes don't have storage, thus LHS=0
            LHS = @expression(model, 0.0)
        else
            # for storage node if t ==1 then state(n, s, t-1) = initial state
            if t == 1
                LHS = @expression(model, state_variables[n.name, s, t] - (1-n.state_loss) * n.initial_state)
            else
                LHS = @expression(model, state_variables[n.name, s, t] - (1-n.state_loss) * state_variables[n.name, s, t-1])
            end
        end

        # Declare constraint
        c = @constraint(model, LHS
                            == sum(flow_variables[i, j, s, t] for (i,j) in input_flows)
                            - sum(flow_variables[i, j, s, t] for (i,j) in output_flows)
                            + n.external_flow[s][t]
                            + shortage_variables[n.name, s, t]
                            - surplus_variables[n.name, s, t])
        
        balance_constraints[n.name, s, t] = c
    end

    balance_constraints
end


# -- Process flows' upper and lower bound constraints --
"""
    function process_flow_constraints(model::Model, structure::ModelStructure,
        flow_variables::Dict{FlowTuple, VariableRef},
        online_variables::Dict{ProcessTuple, VariableRef} = Dict{ProcessTuple, VariableRef}())  

Add upper and lower bound constraints for flexible and online processes to JuMP model.
"""
function process_flow_constraints(model::Model, structure::ModelStructure,
    flow_variables::Dict{FlowTuple, VariableRef},
    online_variables::Dict{ProcessTuple, VariableRef} = Dict{ProcessTuple, VariableRef}())

    # Names of different process types for easy access in constraint generation
    flexible_processes = [p.name for p in structure.flexible_processes]
    online_processes = [p.name for p in structure.online_processes]
    
    # Dictionary for constraints, to be returned from function
    flow_constraints = Dict{FlowTuple, Vector{ConstraintRef}}()

    # Iterate through all process flows and create lower and upper bound constraints
    for f in structure.process_flows, t in structure.T, s in structure.S

        # Flow to or from a flexible process
        if f.source in flexible_processes || f.sink in flexible_processes

            # Upper bound constraint
            c_ub = @constraint(model, flow_variables[f.source, f.sink, s, t] ≤ f.capacity)
            flow_constraints[f.source, f.sink, s, t] = [c_ub]


        # Flow to or from an online process
        elseif f.source in online_processes || f.sink in online_processes
            # Find OnlineProcess structure of process in question (add_flows ensures process flow is always node-process connection so this is safe)
            p = filter(p -> p.name == f.source || p.name == f.sink, structure.online_processes)[1]

            upper_bound = @expression(model, f.capacity * online_variables[p.name, s, t])
            lower_bound = @expression(model, p.min_load * f.capacity * online_variables[p.name, s, t])

            c_ub = @constraint(model, flow_variables[f.source, f.sink, s, t] ≤ upper_bound)
            c_lb = @constraint(model, lower_bound ≤ flow_variables[f.source, f.sink, s, t])
            flow_constraints[f.source, f.sink, s, t] = [c_ub, c_lb]

        end
    end

    flow_constraints
end


# -- Ramp rate of flexible and online processes constraints --
"""
    function process_ramp_rate_constraints(model::Model, structure::ModelStructure, 
        flow_variables::Dict{FlowTuple, VariableRef},
        start_variables::Dict{ProcessTuple, VariableRef} = Dict{ProcessTuple, VariableRef}(),
        stop_variables::Dict{ProcessTuple, VariableRef} = Dict{ProcessTuple, VariableRef}())  

Add ramp rate constraints for flexible and online processes to JuMP model.
"""
function process_ramp_rate_constraints(model::Model, structure::ModelStructure, 
    flow_variables::Dict{FlowTuple, VariableRef},
    start_variables::Dict{ProcessTuple, VariableRef} = Dict{ProcessTuple, VariableRef}(),
    stop_variables::Dict{ProcessTuple, VariableRef} = Dict{ProcessTuple, VariableRef}())

    # Names of different process types for easy access in constraint generation
    flexible_processes = [p.name for p in structure.flexible_processes]
    online_processes = [p.name for p in structure.online_processes]

    # ramping constraints only declared for time steps from 2nd to last
    T_tail = 2:length(structure.T)
    
    # Dictionary for constraints, to be returned from function
    ramp_rate_constraints = Dict{FlowTuple, Vector{ConstraintRef}}()

    # Iterate through all process flows and create lower and upper bound constraints
    for f in structure.process_flows, t in T_tail, s in structure.S
    
        # Flow to or from a flexible process
        if f.source in flexible_processes || f.sink in flexible_processes

            # Find FlexibleProcess structure of process in question (notice add_flows would not allow process-process connection so this is safe)
            p = filter(p -> p.name == f.source || p.name == f.sink, structure.flexible_processes)[1]
            
            c_ub = @constraint(model, flow_variables[f.source, f.sink, s, t] - flow_variables[f.source, f.sink, s, t-1] 
                            ≤ p.ramp_rate * f.capacity)

            c_lb = @constraint(model, -p.ramp_rate * f.capacity 
                            ≤ flow_variables[f.source, f.sink, s, t] - flow_variables[f.source, f.sink, s, t-1])

            ramp_rate_constraints[f.source, f.sink, s, t] = [c_ub, c_lb]


        # Flow to or from an online process
        elseif f.source in online_processes || f.sink in online_processes
            
            # Find OnlineProcess structure of process in question (notice add_flows would not allow process-process connection so this is safe)
            p = filter(p -> p.name == f.source || p.name == f.sink, structure.online_processes)[1]

            lower_bound = @expression(model, - p.ramp_rate * f.capacity
                                - max(0, p.min_load * f.capacity - p.ramp_rate) * stop_variables[p.name, s, t])

            upper_bound = @expression(model, p.ramp_rate * f.capacity
                                + max(0, p.min_load * f.capacity - p.ramp_rate) * start_variables[p.name, s, t])

            c_lb = @constraint(model, lower_bound ≤ flow_variables[f.source, f.sink, s, t] - flow_variables[f.source, f.sink, s, t-1])
            c_ub = @constraint(model, flow_variables[f.source, f.sink, s, t] - flow_variables[f.source, f.sink, s, t-1] ≤ upper_bound)
            ramp_rate_constraints[f.source, f.sink, s, t] = [c_ub, c_lb]

        end # note: vre processes cannot be ramped -> no ramp constraints
    end

    ramp_rate_constraints
end

# -- Process efficiency constraints --
"""
    function process_efficiency_constraints(model::Model, structure::ModelStructure, 
        flow_variables::Dict{FlowTuple, VariableRef})  

Add process efficiency constraints for flexible and online processes to JuMP model.
"""
function process_efficiency_constraints(model::Model, structure::ModelStructure, 
    flow_variables::Dict{FlowTuple, VariableRef})

    # Efficiency constraints apply to flexible and online processes
    processes = [structure.flexible_processes..., structure.online_processes...]

    # Dictionary for constraints, to be returned from function
    efficiency_constraints = Dict{ProcessTuple, ConstraintRef}()

    for p in processes, t in structure.T, s in structure.S

        output_flows = filter(f -> f.source == p.name, structure.process_flows)
        output_flows = map(f -> (f.source, f.sink), output_flows)

        input_flows = filter(f -> f.sink == p.name, structure.process_flows)
        input_flows = map(f -> (f.source, f.sink), input_flows)

        c = @constraint(model, sum(flow_variables[i, j, s, t] for (i,j) in output_flows) 
                            == p.efficiency[s][t] * sum(flow_variables[i, j, s, t] for (i,j) in input_flows))

        efficiency_constraints[p.name, s, t] = c
    end

    efficiency_constraints

end

# -- Online/offline functionality constraints --
"""
    function online_functionality_constraints(model::Model, structure::ModelStructure,
        start_variables::Dict{NodeTuple, VariableRef},
        stop_variables::Dict{NodeTuple, VariableRef},
        online_variables::Dict{NodeTuple, VariableRef})  

Add online offline functionality constraints for online processes to JuMP model.
"""
function online_functionality_constraints(model::Model, structure::ModelStructure,
    start_variables::Dict{NodeTuple, VariableRef},
    stop_variables::Dict{NodeTuple, VariableRef},
    online_variables::Dict{NodeTuple, VariableRef})

    # Find last time step for ease in constraint generation
    t_max = length(structure.T)

    # Dictionaries of constraints, to be returned from function
    on_off_constraints = Dict{ProcessTuple, ConstraintRef}()
    min_online_constraints = Dict{ProcessTuple, Vector{ConstraintRef}}()
    min_offline_constraints = Dict{ProcessTuple, Vector{ConstraintRef}}()

    for p in structure.online_processes, t in structure.T, s in structure.S
        
        # Set initial status constraint 
        if t == 1 # set initial status
            c = @constraint(model, online_variables[p.name, s, t] == p.initial_status) 
            on_off_constraints[p.name, s, t] = c
        
        # Set on/off functionality constraints for later time steps
        else
            c = @constraint(model, online_variables[p.name, s, t] 
                            == online_variables[p.name, s, t-1] + start_variables[p.name, s, t] - stop_variables[p.name, s, t])
            
            on_off_constraints[p.name, s, t] = c
        end

        # Set min online time constraints
        for t2 in t:min(t_max, t+p.min_online)
            c_min_online = @constraint(model, online_variables[p.name, s, t2] ≥ start_variables[p.name, s, t])

            # Insert constraints by first initialising key [p.name, s, t] and then pushing to this vector
            if t2 == t
                min_online_constraints[p.name, s, t] = [c_min_online]
            else
                push!(min_online_constraints[p.name, s, t], c_min_online)
            end
        end

        # Set min offline time constraints
        for t3 in t:min(t_max, t+p.min_offline)
            c_min_offline = @constraint(model, online_variables[p.name, s, t3] ≤ 1 - stop_variables[p.name, s, t])

            # Insert constraints by first initialising key [p.name, s, t] and then pushing to this vector
            if t3 == t
                min_offline_constraints[p.name, s, t] = [c_min_offline]
            else
                push!(min_offline_constraints[p.name, s, t], c_min_offline)
            end
        end

    end

    on_off_constraints, min_online_constraints, min_offline_constraints
end


# -- Capacity factor constraints --
"""
    function cf_flow_constraints(model::Model, structure::ModelStructure,
        flow_variables::Dict{FlowTuple, VariableRef})  

Add capacity factor upper bound constraints for output flows of processes to JuMP model.
"""
function cf_flow_constraints(model::Model, structure::ModelStructure,
    flow_variables::Dict{FlowTuple, VariableRef})

        # Fetch names and structs of processes for easy access during constraint generation
        process_names = get_names(structure, processes=true)
        processes = [structure.flexible_processes..., structure.vre_processes..., structure.online_processes...]

        # Dictionary for constraints, to be returned from function
        cf_constraints = Dict{FlowTuple, ConstraintRef}()

        for f in structure.process_flows, s in structure.S, t in structure.T
            # Create constraints only for output flows of processes
            if f.source in process_names

                # Find VREProcess structure of process in question
                p = filter(p -> p.name == f.source, processes)[1]

                c = @constraint(model, flow_variables[f.source, f.sink, s, t] ≤ f.capacity * p.cf[s][t])
                
                cf_constraints[f.source, f.sink, s, t] = c

            end
        end

        cf_constraints
end