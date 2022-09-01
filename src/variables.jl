using JuMP


"""
    const FlowTuple = Tuple{String, String, Int64, Int64}

Type for flow variables' indices. Alias for Tuple with source, sink, time step and scenario.
"""
const FlowTuple = Tuple{String, String, Int64, Int64}


"""
    const NodeTuple = Tuple{String, Int64, Int64}

Type for state, shortage and surplus variables' indices. Alias for Tuple with node name, time step and scenario.
"""
const NodeTuple = Tuple{String, Int64, Int64}


"""
    const ProcessTuple = Tuple{String, Int64, Int64}

Type for start, stop and online variables' indices. Alias for Tuple with process name, time step and scenario.
"""
const ProcessTuple = Tuple{String, Int64, Int64}


"""
    function flow_variables(model::Model, structure::ModelStructure)

Declare JuMP variables for all flows in model structure with zero lower bounds. 
    
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

        # create variable with readable name of form f(source, sink, s, t)
        v = @variable(model, 
        base_name = string("f($(f.source), $(f.sink), s$s, t$t)"),
        lower_bound = 0)

        # add variable to dictionary for easy access
        flow_variables[(f.source, f.sink, s, t)] = v
    end

    flow_variables
end


"""
    function state_variables(model::Model, structure::ModelStructure)

Declare JuMP variables for states of all storage nodes with zero lower bounds and maximum state upper bounds declared. 
    
    Return variables in Dict{NodeTuple, VariableRef}.
"""
function state_variables(model::Model, structure::ModelStructure)
        # scerios and time steps
        S = structure.S
        T = structure.T

        state_variables = Dict{NodeTuple, VariableRef}()
    
        for n in structure.storage_nodes, s in S, t in T
    
            # create variable with readable name of form f(source, sink, s, t)
            v = @variable(model, 
                base_name = string("s($(n.name), s$s, t$t)"), 
                lower_bound = 0, 
                upper_bound = n.state_max)

    
            # add variable to dictionary for easy access
            state_variables[(n.name, s, t)] = v
        end
    
        state_variables
end


"""
    function shortage_surplus_variables(model::Model, structure::ModelStructure)

Declare shortage and surplus JuMP variables for all energy and storage nodes with zero lower bounds declared.

    Return shortage and surplus variables in Dict{NodeTuple, VariableRef}, Dict{NodeTuple, VariableRef} format.
"""
function shortage_surplus_variables(model::Model, structure::ModelStructure)
    # scerios and time steps
    S = structure.S
    T = structure.T

    shortage_variables = Dict{NodeTuple, VariableRef}()
    surplus_variables = Dict{NodeTuple, VariableRef}()
   
    # energy balance in maintained over energy nodes and storage nodes
    balance_nodes = [structure.energy_nodes..., structure.storage_nodes...]

    for n in balance_nodes, s in S, t in T

        # create variable with readable name of form f(source, sink, s, t)
        v_shortage = @variable(model, 
                    base_name = string("shortage($(n.name), s$s, t$t)"), 
                    lower_bound = 0)
        v_surplus = @variable(model, 
                    base_name = string("surplus($(n.name), s$s, t$t)"),
                    lower_bound = 0)
        
        # add variables to dictionaries for easy access
        shortage_variables[(n.name, s, t)] = v_shortage
        surplus_variables[(n.name, s, t)] = v_surplus
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

        # create variable with readable name of form f(source, sink, s, t)
        v_start = @variable(model, base_name = string("start($(p.name), s$s, t$t)"), binary = true)
        v_stop = @variable(model, base_name = string("stop($(p.name), s$s, t$t)"), binary = true)
        v_online = @variable(model, base_name = string("online($(p.name), s$s, t$t)"), binary = true)
    
        # add variable to dictionary for easy access
        start_variables[(p.name, s, t)] = v_start
        stop_variables[(p.name, s, t)] = v_stop
        online_variables[(p.name, s, t)] = v_online
    end

    start_variables, stop_variables, online_variables
end


