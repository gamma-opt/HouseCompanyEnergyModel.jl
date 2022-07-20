
abstract type AbstractNode end
abstract type AbstractProcess end




# --- Time steps, scenarios and time series ---

"""
    const TimeSteps = UnitRange{Int}

Type for time steps at time intervals of 1. Alias for UnitRange{Int}
"""
const TimeSteps = UnitRange{Int}

"""
    function time_steps(n_time_steps::Int)

Constructor function for TimeSteps from 1 to n_time_steps. Time steps spaced by one.
"""
function time_steps(n_time_steps::Int)
     TimeSteps(1,n_time_steps)
end


"""
    const Scenarios = UnitRange{Int}

Type for scenarios. Alias for UnitRange{Int}
"""
const Scenarios = UnitRange{Int}

"""
    function scenarios(n_scenarios::Int)

Constructor function for n number of scenarios.
"""
function scenarios(n_scenarios::Int)
    Scenarios(1,n_scenarios)
end



"""
    const TimeSeries = Vector{Vector{Float64}}

Type for storing a vector containing time series values for each scenario. 
If B is of type TimeSeries, then B[s][t] should give to value at time t in scenario s.
"""
const TimeSeries = Vector{Vector{Float64}}

function time_series(timeseries::Vector{Vector{Float64}}, S::Scenarios, T::TimeSteps)
    if length(S) != length(timeseries)
        throw(DomainError("There must be a time series for each scenario."))
    elseif !all(length(ts) == length(T) for ts in timeseries)
        throw(DomainError("All time series must be of the same length as number of timesteps in model."))
    end
    TimeSeries(timeseries)
end


# --- Nodes ---
"""
const Name = String

Type alias for String to ease reading of names.
"""
const Name = String

struct PlainNode <: AbstractNode
    name::Name
    external_flow::TimeSeries
end

function plain_node(name::Name, external_flow::TimeSeries, S::Scenarios, T::TimeSteps)
    external_flow = time_series(external_flow, S, T)
    PlainNode(name, external_flow)
end

struct StorageNode <: AbstractNode
    name::Name
    in_flow_max::Float64
    out_flow_max::Float64
    state_max::Float64
    state_loss::Float64
    external_flow::TimeSeries
    initial_state::Float64
end

function storage_node(name::Name, in_flow_max::Float64, out_flow_max::Float64, 
    state_max::Float64, state_loss::Float64, 
    external_flow::TimeSeries, S::Scenarios, T::TimeSteps, initial_state=0)    

    external_flow = time_series(external_flow, S, T)
    if !(0 <= state_loss <= 1)
        throw(DomainError("State loss must be between 0 and 1."))
    elseif !(initial_state <= state_max)
        throw(DomainError("Initial state cannot exceed maximum state."))
    end  
    StorageNode(name, in_flow_max, out_flow_max, state_max, state_loss, external_flow, initial_state)
end


struct CommodityNode <: AbstractNode
    name::Name
    cost::TimeSeries
end

function commodity_node(name::Name, cost::TimeSeries, S::Scenarios, T::TimeSteps)
    cost = time_series(cost, S, T)
    CommodityNode(name, cost)
end

struct MarketNode <: AbstractNode
    name::Name
    price::TimeSeries
end

function market_node(name::Name, price::TimeSeries, S::Scenarios, T::TimeSteps)
    price = time_series(price, S, T)
    MarketNode(name, price)
end



# --- Processes ---

struct PlainUnitProcess <: AbstractProcess
    name::Name
    efficiency::TimeSeries
end

function plain_unit_process(name::Name, efficiency::TimeSeries, S::Scenarios, T::TimeSteps)
    efficiency = time_series(efficiency, S, T)
    if !all(0 <= efficiency[s][t] <= 1 for s in S, t in T)
        throw(DomainError("Efficiency values must be between 0 and 1."))
    end

    PlainUnitProcess(name, efficiency)
end


struct CFUnitProcess <: AbstractProcess
    name::Name
    efficiency::TimeSeries
    cf::TimeSeries
end

function cf_unit_process(name::Name, efficiency::TimeSeries, cf::TimeSeries, S::Scenarios, T::TimeSteps)
    efficiency = time_series(efficiency, S, T)
    cf = time_series(cf, S, T)
    if !all(0 <= efficiency[s][t] <= 1 for s in S, t in T)
        throw(DomainError("Efficiency values must be between 0 and 1."))
    end
    if !all(0 <= cf[s][t] <= 1 for s in S, t in T)
        throw(DomainError("Capacity factor values must be between 0 and 1."))
    end

    CFUnitProcess(name, efficiency, cf)
end

struct OnlineUnitProcess <: AbstractProcess
    name::Name
    efficiency::TimeSeries
    min_load::Float64
    min_online::Int
    min_offline::Int
    start_cost::Float64
    initial_status::Int
end

function online_unit_process(name::Name, efficiency::TimeSeries, S::Scenarios, T::TimeSteps,
    min_load::Float64, min_online::Int, min_offline::Int,
    start_cost::Float64, initial_status::Int=1)
    
    efficiency = time_series(efficiency, S, T)
    if !all(0 <= efficiency[s][t] <= 1 for s in S, t in T)
        throw(DomainError("Efficiency values must be between 0 and 1."))
    elseif !(0 <= min_load <= 1)
        throw(DomainError("Minimum load must be between 0 and 1."))
    elseif !(0 == initial_status || 1 == initial_status)
        throw(DomainError("Initial status must be 0 or 1."))
    end

    OnlineUnitProcess(name, efficiency, min_load, min_online, min_offline, start_cost, initial_status)
end



# --- Flow ---
"""
    struct Flow
        source::Name
        sink::Name
        capacity::TimeSeries
        VOM_cost::Float64
        ramp_up::Float64
        ramp_down::Float64
    end

A struct for modeling flow connecting node-node or process-node pairs. 

# Fields
- `source::Name`: Name of the source of the topology.
- `sink::Name`: Name of the sink of the topology.
- `capacity::TimeSeries`: Upper limit of the flow variable. 
- `VOM_cost::Float64`: VOM cost of using this connection. 
- `ramp_up::Float64`: Maximum allowed increase of the linked flow variable value between timesteps. Min 0.0 max 1.0. 
- `ramp_down::Float64`: Minimum allowed increase of the linked flow variable value between timesteps. Min 0.0 max 1.0.
"""
struct Flow
    source::Name
    sink::Name
    capacity::TimeSeries
    VOM_cost::Float64
    ramp_up::Float64
    ramp_down::Float64
end

function flow(source::Name, sink::Name, 
    capacity::TimeSeries, S::Scenarios, T::TimeSteps, 
    VOM_cost::Float64, ramp_up::Float64, ramp_down::Float64)

    capacity = time_series(capacity, S, T)
    if source == sink
        throw(DomainError("The source and sink of a flow cannot be the same."))
    if !(0 <= ramp_up <= 1)
        throw(DomainError("Ramp up value must be between 0 and 1."))
    elseif !(0 <= ramp_down <= 1)
        throw(DomainError("Ramp DOWN value must be between 0 and 1."))
    end

    Flow(source, sink, capacity, VOM_cost, ramp_up, ramp_down)
end



# --- NetworkModel ---


"""
    mutable struct NetworkModel
        temporals::Temporals
        processes::OrderedDict{String, Process}
        nodes::OrderedDict{String, Node}
        markets::OrderedDict{String, Market}
        scenarios::OrderedDict{String, Float64}
        reserve_type::OrderedDict{String, Float64}
        risk::OrderedDict{String, Float64}
        gen_constraints::OrderedDict{String, GenConstraint}
    end

Struct containing the imported input data, based on which the Predicer is built.
# Fields
- `temporals::Temporals`: The timesteps in the model as a Temporals struct.
- `processes::OrderedDict{String, Process}`: A dict containing the data relevant for processes.
- `nodes::OrderedDict{String, Node}`: A dict containing the data relevant for nodes.
- `markets::OrderedDict{String, Market}`: A dict containing the data relevant for markets.
- `scenarios::OrderedDict{String, Float64}`:  A dict containing the data relevant for scenarios, with scenario name as key and probability as value.
- `reserve_type::OrderedDict{String, Float64}`:  A dict containing the reserve types, with reserve name as key and ramp rate(speed) as value: 1 = 1 hour reaction time, 4 = 15 minutes reaction time, etc. 
- `risk::OrderedDict{String, Float64}`:  A dict containing the data on risk for the cvar calculations, with the risk parameter as key and risk value as value. 
- `gen_constraints::OrderedDict{String, GenConstraint}`:  A dict containing the genconstraints.
"""
mutable struct NetworkModel
    S::Scenarios
    T::TimeSteps
    plain_nodes::Vector{PlainNode}
    storage_nodes::Vector{StorageNode}
    commodity_nodes::Vector{CommodityNode}
    market_nodes::Vector{MarketNode}
    plain_processes::Vector{PlainUnitProcess}
    cf_processes::Vector{CFUnitProcess}
    online_processes::Vector{OnlineUnitProcess}
    flows::Vector{Flow}

    function NetworkModel(S::Scenarios, T::Timesteps)
        new(S, T, [], [], [], [], [], [], [], [])
    end
end

# --- Adding nodes ---

function names(structure::ModelStructure; nodes::Bool=false, processes::Bool=false)
    all_names = []

    if nodes
        push!(all_names, [(n.name for n in structure.plain_nodes)...])
        push!(all_names, [(n.name for n in structure.storage_nodes)...])
        push!(all_names, [(n.name for n in structure.commodity_nodes)...])
        push!(all_names, [(n.name for n in structure.market_nodes)...])
    end

    if processes
        push!(all_names, [(p.name for p in structure.plain_processes)...])
        push!(all_names, [(p.name for p in structure.cf_processes)...])
        push!(all_names, [(p.name for p in structure.online_processes)...])
    end
    return all_names
end


function add_nodes!(structure::ModelStructure, nodes::Vector{AbstractNode})
    for n in nodes
        
        names = names(structure, nodes=true, processes=true)
        if n.name in names
            throw(DomainError("Name $n.name is not unique. Name must be unique."))
        end

        if isa(n, PlainNode)
            push!(structure.plain_nodes, n)

        elseif isa(n, StorageNode)
            push!(structure.storage_nodes, n)

        elseif isa(n, CommodityNode)
            push!(structure.commodity_nodes, n)

        elseif isa(n, MarketNode)
            push!(structure.market_nodes, n)

        else
            throw(DomainError("Node $n node type is not recognised.")) 
        end
    end
end


function add_processes!(structure::ModelStructure, processes::Vector{AbstractProcess})
    for p in processes
        
        names = names(structure, nodes=true, processes=true)
        if p.name in names
            throw(DomainError("Name $p.name is not unique. Name must be unique."))
        end

        if isa(p, PlainUnitProcess)
            push!(structure.plain_processes, p)

        elseif isa(p, CFUnitProcess)
            push!(structure.cf_processes, p)

        elseif isa(p, OnlineUnitProcess)
            push!(structure.online_processes, p)

        else
            throw(DomainError("Process $p type is not recognised.")) 
        end
    end
end


function add_flows!(structure::ModelStructure, flows::Vector{Flow})
    names = names(structure, nodes=true, processes=true)
    nodes = names(structure, nodes=true)
    processes = names(structure, processes=true)
    market_nodes = (n.name for n in structure.market_nodes)
    commodity_nodes = (n.name for n in structure.commodity_nodes)

    for f in flows
        
        if !(f.source in names)
            throw(DomainError("Source of flow ($f.source -> $f.sink) not found in model structure.")) 

        elseif !(f.sink in names)
            throw(DomainError("Sink of flow ($f.source -> $f.sink) not found in model structure.")) 

        elseif f.source in processes && !(f.sink in nodes)
            throw(DomainError("Flow from a unit process has to go to a node. Issue in ($f.source -> $f.sink)"))

        elseif f.sink in processes && !(f.source in nodes)
            throw(DomainError("Flow to a unit process has to come from a node. Issue in ($f.source -> $f.sink)"))

        elseif f.sink in commodity_nodes
            throw(DomainError("A commodity node cannot be a sink. Issue in ($f.source -> $f.sink)"))

        elseif f.source in market_nodes && !(f.sink in nodes)
            throw(DomainError("A market node cannot be a connected to a unit process. Issue in ($f.source -> $f.sink)"))

        elseif f.sink in market_nodes && !(f.source in nodes)
            throw(DomainError("A market node cannot be a connected to a unit process. Issue in ($f.source -> $f.sink)"))
        end

    end


    # Check that market nodes have symmetric flows to nodes
    market_input_flows = filter(f -> f.sink in market_nodes, flows)
    market_input_names = [(f.source for f in market_input_flows)...]
    market_output_flows = filter(f -> f.source in market_nodes, flows)
    market_output_names = [(f.sink for f in market_output_flows)...]
    if !issetequal(Set(market_input_names), Set(market_output_names))
        throw(DomainError("The arcs to and from market nodes should be symmetric."))
    end

    # Check that all nodes and processes are connected to the network by some flow
    all_sources = [(f.source for f in flows)...]
    all_sinks = [(f.sink for f in flows)...]
    all_endpoints = unique([all_sources..., all_sinks...])
    for i in names
        if !(i in all_endpoints)
            throw(DomainError("Node or process $i is not an endpoint to any flow."))
        end
    end

    # if all checks passed, push flows to model structure
    push!(structure.flows, flows)
end