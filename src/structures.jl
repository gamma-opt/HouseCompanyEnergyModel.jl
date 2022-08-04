

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

function validate_time_series(timeseries::Vector{Vector{Float64}}, S::Scenarios, T::TimeSteps)
    if length(S) != length(timeseries)
        throw(DomainError("There must be a time series for each scenario."))
    elseif !all(length(ts) == length(T) for ts in timeseries)
        throw(DomainError("All time series must be of the same length as number of timesteps in model."))
    end
    true
end


# --- Nodes ---

abstract type AbstractNode end

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
    validate_time_series(external_flow, S, T)
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

    validate_time_series(external_flow, S, T)
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
    validate_time_series(cost, S, T)
    CommodityNode(name, cost)
end

struct MarketNode <: AbstractNode
    name::Name
    price::TimeSeries
end

function market_node(name::Name, price::TimeSeries, S::Scenarios, T::TimeSteps)
    validate_time_series(price, S, T)
    MarketNode(name, price)
end



# --- Processes ---

abstract type AbstractProcess end

struct PlainUnitProcess <: AbstractProcess
    name::Name
    efficiency::TimeSeries
end

function plain_unit_process(name::Name, efficiency::TimeSeries, S::Scenarios, T::TimeSteps)
    validate_time_series(efficiency, S, T)
    if !all(0 <= efficiency[s][t] <= 1 for s in S, t in T)
        throw(DomainError("Efficiency values must be between 0 and 1."))
    end

    PlainUnitProcess(name, efficiency)
end


struct CFUnitProcess <: AbstractProcess
    name::Name
    cf::TimeSeries
end

function cf_unit_process(name::Name, cf::TimeSeries, S::Scenarios, T::TimeSteps)
    validate_time_series(cf, S, T)

    if !all(0 <= cf[s][t] <= 1 for s in S, t in T)
        throw(DomainError("Capacity factor values must be between 0 and 1."))
    end

    CFUnitProcess(name, cf)
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
    
    validate_time_series(efficiency, S, T)
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

abstract type AbstractFlow end

"""
    struct ProcessFlow <: AbstractFlow
        source::Name
        sink::Name
        capacity::TimeSeries
        VOM_cost::Float64
        ramp_rate::Float64
    end

A struct for modeling flow connecting node-node or process-node pairs. 

# Fields
- `source::Name`: Name of the source of the topology.
- `sink::Name`: Name of the sink of the topology.
- `capacity::TimeSeries`: Upper limit of the flow variable. 
- `VOM_cost::Float64`: VOM cost of using this connection. 
- `ramp_rate::Float64`: Maximum allowed change of the linked flow variable value between timesteps. Min 0.0 max 1.0. 
"""
struct ProcessFlow <: AbstractFlow
    source::Name
    sink::Name
    capacity::TimeSeries
    VOM_cost::Float64
    ramp_rate::Float64
end

function process_flow(source::Name, sink::Name, 
    capacity::TimeSeries, S::Scenarios, T::TimeSteps, 
    VOM_cost::Float64, ramp_rate::Float64)

    validate_time_series(capacity, S, T)
    if source == sink
        throw(DomainError("The source and sink of a flow cannot be the same."))
    elseif !(0 <= ramp_rate <= 1)
        throw(DomainError("Ramp rate value must be between 0 and 1."))
    end

    ProcessFlow(source, sink, capacity, VOM_cost, ramp_rate)
end

"""
    struct TransferFlow <: AbstractFlow
        source::Name
        sink::Name
    end

Flow structure for one directional transfer of energy between a market and a node.
"""
struct TransferFlow <: AbstractFlow
    source::Name
    sink::Name
end

function transfer_flow(source::Name, sink::Name)

    if source == sink
        throw(DomainError("The source and sink of a flow cannot be the same."))
    end

    TransferFlow(source, sink)
end

"""
    struct MarketFlow <: AbstractFlow
        source::Name
        sink::Name
    end

Flow structure for two directional transfer of energy between two nodes. 

The source and sink are treated identically meaning the connected nodes can be inserted either way around.

!!! note
    Either source or sink has to be the name of a MarketNode.
"""
struct MarketFlow <: AbstractFlow
    source::Name
    sink::Name
end

function market_flow(source::Name, sink::Name)

    if source == sink
        throw(DomainError("The source and sink of a flow cannot be the same."))
    end

    MarketFlow(source, sink), MarketFlow(sink, source)
end

# --- ModelStructure ---


"""
    mutable struct ModelStructure
        S::Scenarios
        T::TimeSteps
        plain_nodes::Vector{PlainNode}
        storage_nodes::Vector{StorageNode}
        commodity_nodes::Vector{CommodityNode}
        market_nodes::Vector{MarketNode}
        plain_processes::Vector{PlainUnitProcess}
        cf_processes::Vector{CFUnitProcess}
        online_processes::Vector{OnlineUnitProcess}
        process_flows::Vector{ProcessFlow}
        transfer_flows::Vector{TransferFlow}
        market_flows::Vector{MarketFlow}

        function ModelStructure(S::Scenarios, T::TimeSteps)
            new(S, T, [], [], [], [], [], [], [], [])
        end
    end

Struct containing the scenarios, timesteps, nodes, processes and flows in the model.
"""
mutable struct ModelStructure
    S::Scenarios
    T::TimeSteps
    plain_nodes::Vector{PlainNode}
    storage_nodes::Vector{StorageNode}
    commodity_nodes::Vector{CommodityNode}
    market_nodes::Vector{MarketNode}
    plain_processes::Vector{PlainUnitProcess}
    cf_processes::Vector{CFUnitProcess}
    online_processes::Vector{OnlineUnitProcess}
    process_flows::Vector{ProcessFlow}
    transfer_flows::Vector{TransferFlow}
    market_flows::Vector{MarketFlow}

    function ModelStructure(S::Scenarios, T::TimeSteps)
        new(S, T, [], [], [], [], [], [], [], [], [], [])
    end
end

# --- Filling ModelStructure ---
"""
    function get_names(structure::ModelStructure; nodes::Bool=false, processes::Bool=false)

Return vector of nodes' and/or processes' names.
"""
function get_names(structure::ModelStructure; nodes::Bool=false, processes::Bool=false)
    all_names = []

    if nodes
        push!(all_names, map(n -> n.name, structure.plain_nodes)...)
        push!(all_names, map(n -> n.name, structure.storage_nodes)...)
        push!(all_names, map(n -> n.name, structure.commodity_nodes)...)
        push!(all_names, map(n -> n.name, structure.market_nodes)...)
    end

    if processes
        push!(all_names, map(n -> n.name, structure.plain_processes)...)
        push!(all_names, map(n -> n.name, structure.cf_processes)...)
        push!(all_names, map(n -> n.name, structure.online_processes)...)
    end
    return all_names
end


"""
    function get_flows(structure::ModelStructure; names=false)

Return vector of flows in structure. If names=true, then return list of (source, sink) pairs of names. 
"""
function get_flows(structure::ModelStructure; names=false)
    
    if names
        flows = []

        for f in structure.process_flows
            push!(flows, (f.source, f.sink))
        end
        for f in structure.transfer_flows
            push!(flows, (f.source, f.sink))
        end
        for f in structure.market_flows
            push!(flows, (f.source, f.sink))
        end
    else
        flows = [structure.process_flows..., structure.transfer_flows..., structure.market_flows...]
    end

    return flows
end


function add_nodes!(structure::ModelStructure, nodes::Vector{N}) where N<:AbstractNode
    for n in nodes
        
        names = get_names(structure, nodes=true, processes=true)
        if n.name in names
            throw(DomainError("Name $(n.name) is not unique. Name must be unique."))
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


function add_processes!(structure::ModelStructure, processes::Vector{N}) where N<:AbstractProcess
    for p in processes
        
        names = get_names(structure, nodes=true, processes=true)
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


function add_flows!(structure::ModelStructure, flows::Vector{N}) where N<:AbstractFlow
    names = get_names(structure, nodes=true, processes=true)
    nodes = get_names(structure, nodes=true)
    processes = get_names(structure, processes=true)
    market_nodes = (n.name for n in structure.market_nodes)
    commodity_nodes = (n.name for n in structure.commodity_nodes)
    cf_processes = (p.name for p in structure.cf_processes)
    flow_names = get_flows(structure, names=true)

    for f in flows
        ## Check flow type specific constraints
        if isa(f, ProcessFlow)
            if !(f.source in processes || f.sink in processes)
                throw(DomainError("The source or sink of a ProcessFlow must be a process. Issue in ($(f.source) -> $(f.sink))."))
            end

        elseif isa(f, TransferFlow)
            if f.source in processes || f.sink in processes
                throw(DomainError("The a flow connected to a process must be of type ProcessFlow. Issue in ($(f.source) -> $(f.sink))."))

            elseif f.source in market_nodes || f.sink in market_nodes
                throw(DomainError("A market node cannot be connected with a one directional TransferFlow. Use MarketFlow for two directional flows. Issue in ($(f.source) -> $(f.sink))."))
            end

        elseif isa(f, MarketFlow)
            if !(f.source in market_nodes || f.sink in market_nodes)
                throw(DomainError("Either the source or sink of a MarketFlow must be a market node. Issue in ($(f.source) -> $(f.sink))."))
            end
        end

        ## Check model logic specific constraints
        if !(f.source in names)
            throw(DomainError("Source of flow ($(f.source) -> $(f.sink)) not found in model structure."))

        elseif !(f.sink in names)
            throw(DomainError("Sink of flow ($(f.source) -> $(f.sink)) not found in model structure."))

        elseif (f.source, f.sink) in flow_names
            throw(DomainError("Flow ($(f.source) -> $(f.sink)) already exists, cannot add flow twice."))

        elseif f.source in processes && !(f.sink in nodes)
            throw(DomainError("Flow from a unit process has to go to a node. Issue in ($(f.source) -> $(f.sink))"))

        elseif f.sink in processes && !(f.source in nodes)
            throw(DomainError("Flow to a unit process has to come from a node. Issue in ($(f.source) -> $(f.sink))"))

        elseif f.sink in commodity_nodes
            throw(DomainError("A commodity node cannot be a sink. Issue in ($(f.source) -> $(f.sink))"))
        
        elseif f.sink in cf_processes
            throw(DomainError("A CF process cannot be a sink. Issue in ($(f.source) -> $(f.sink))"))

        elseif f.source in market_nodes && !(f.sink in nodes)
            throw(DomainError("A market node cannot be a connected to a unit process. Issue in ($(f.source) -> $(f.sink))"))

        elseif f.sink in market_nodes && !(f.source in nodes)
            throw(DomainError("A market node cannot be a connected to a unit process. Issue in ($(f.source) -> $(f.sink))"))

        elseif f.source in market_nodes && f.sink in market_nodes
            throw(DomainError("A market node cannot be a connected to another market node. Issue in ($(f.source) -> $(f.sink))"))
        
        end

    end

    # if all checks passed, push flows to model structure
    for f in flows
        if isa(f, ProcessFlow)
            push!(structure.process_flows, f)

        elseif isa(f, TransferFlow)
            push!(structure.transfer_flows, f)

        elseif isa(f, MarketFlow)
            push!(structure.market_flows, f)

        end
    end
end

function validate_network(structure::ModelStructure)

    # Check that all nodes and processes are connected to flow
    all_sources = map(f -> f.source, get_flows(structure))
    all_sinks = map(f -> f.sink, get_flows(structure))
    names = get_names(structure, nodes=true, processes=true)
    for i in names
        if !(i in [all_sources..., all_sinks...])
            throw(DomainError("Node or process $i is not an end point to any flow."))
        end
    end

    true
end