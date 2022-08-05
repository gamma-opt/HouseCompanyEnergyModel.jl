using JuMP


"""
    const FlowTuple = Tuple{String, String, Int64, Int64}

Type for flow variable indices. Alias for NamedTuple with source, sink, time step and scenario.
"""
const FlowTuple = Tuple{String, String, Int64, Int64}


"""
    const NodeTuple = Tuple{String, Int64, Int64}

Type for state, shortage and surplus variables' indices. Alias for NamedTuple with node, time step and scenario.
"""
const NodeTuple = Tuple{String, Int64, Int64}


"""
    const ProcessTuple = Tuple{String, Int64, Int64}

Type for start, stop and online variables' indices. Alias for NamedTuple with process, time step and scenario.
"""
const ProcessTuple = Tuple{String, Int64, Int64}


"""
    function flow_variables(model::Model, structure::ModelStructure)

Declare JuMP variables for all flows with lower bounds declared. 
    
    Return variables in Dict{FlowTuple, VariableRef}.
"""
function flow_variables(model::Model, structure::ModelStructure)
   
    # scerios and time steps
    S = structure.S
    T = structure.T
    # all flows in model
    flows = get_flows(structure)

    flow_variables = Dict{FlowTuple, VariableRef}()

    for f in flows, s in S, t in T

        # create variable with readable name of form f(source, sink, t, s)
        v = @variable(model, base_name = string("f($(f.source), $(f.sink), t$t, s$s)"))
        
    
        @constraint(model, v ≥ 0)

        # add variable to dictionary for easy access
        flow_variables[(f.source, f.sink, t, s)] = v
    end

    flow_variables
end


"""
    function state_variables(model::Model, structure::ModelStructure)

Declare JuMP variables for states of all storage nodes with lower and upper bounds declared. 
    
    Return variables in Dict{NodeTuple, VariableRef}.
"""
function state_variables(model::Model, structure::ModelStructure)
        # scerios and time steps
        S = structure.S
        T = structure.T

        state_variables = Dict{NodeTuple, VariableRef}()
    
        for n in structure.storage_nodes, s in S, t in T
    
            # create variable with readable name of form f(source, sink, t, s)
            v = @variable(model, base_name = string("s($(n.name), t$t, s$s)"))
            
        
            @constraint(model, v ≥ 0)

            @constraint(model, v ≤ n.state_max)
    
            # add variable to dictionary for easy access
            state_variables[(n.name, t, s)] = v
        end
    
        state_variables
end


"""
    function shortage_surplus_variables(model::Model, structure::ModelStructure)

Declare shortage and surplus JuMP variables for all plain and storage nodes with lower bounds declared.

Return shortage and surplus variables in Dict{NodeTuple, VariableRef}, Dict{NodeTuple, VariableRef} format.
"""
function shortage_surplus_variables(model::Model, structure::ModelStructure)
    # scerios and time steps
    S = structure.S
    T = structure.T

    shortage_variables = Dict{NodeTuple, VariableRef}()
    surplus_variables = Dict{NodeTuple, VariableRef}()
   
    # plain nodes and storage nodes are the only ones were balance is maintained (not in commodity or market nodes)
    balance_nodes = [structure.plain_nodes..., structure.storage_nodes...]

    for n in balance_nodes, s in S, t in T

        # create variable with readable name of form f(source, sink, t, s)
        v_shortage = @variable(model, base_name = string("shortage($(n.name), t$t, s$s)"))
        v_surplus = @variable(model, base_name = string("surplus($(n.name), t$t, s$s)"))

        @constraint(model, v_shortage ≥ 0)
        @constraint(model, v_surplus ≥ 0)
        
        # add variables to dictionaries for easy access
        shortage_variables[(n.name, t, s)] = v_shortage
        surplus_variables[(n.name, t, s)] = v_surplus
    end

    shortage_variables, surplus_variables
end


"""
    function start_stop_online_variables(model::Model, structure::ModelStructure)

Declare binary JuMP variables for start, stop and online indication of all online processes. 
    
    Return start, stop, online variables in Dict{NodeTuple, VariableRef}, Dict{NodeTuple, VariableRef}, Dict{NodeTuple, VariableRef} format.
"""
function start_stop_online_variables(model::Model, structure::ModelStructure)
    # scerios and time steps
    S = structure.S
    T = structure.T

    start_variables = Dict{ProcessTuple, VariableRef}()
    stop_variables = Dict{ProcessTuple, VariableRef}()
    online_variables = Dict{ProcessTuple, VariableRef}()

    for p in structure.online_processes, s in S, t in T

        # create variable with readable name of form f(source, sink, t, s)
        v_start = @variable(model, base_name = string("start($(p.name), t$t, s$s)"), binary = true)
        v_stop = @variable(model, base_name = string("stop($(p.name), t$t, s$s)"), binary = true)
        v_online = @variable(model, base_name = string("online($(p.name), t$t, s$s)"), binary = true)
    
        # add variable to dictionary for easy access
        start_variables[(p.name, t, s)] = v_start
        stop_variables[(p.name, t, s)] = v_stop
        online_variables[(p.name, t, s)] = v_online
    end

    start_variables, stop_variables, online_variables
end


