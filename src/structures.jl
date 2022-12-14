

# --- Time steps, scenarios and time series ---

"""
    const TimeSteps = UnitRange{Int}

Type for time steps at time intervals of 1 time unit. Alias for UnitRange{Int}
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
If B is of type TimeSeries, then B[s][t] should give value at time t in scenario s.
"""
const TimeSeries = Vector{Vector{N}} where N<:Number


"""
    function validate_time_series(timeseries::Vector{Vector{Float64}}, S::Scenarios, T::TimeSteps)

Function for validating structure of time series is compatible with scenarios S and time steps T.
"""
function validate_time_series(timeseries::Vector{Vector{N}}, S::Scenarios, T::TimeSteps) where N<:Number
    if length(S) != length(timeseries)
        throw(DomainError("There must be a time series for each scenario."))
    elseif !all(length(ts) == length(T) for ts in timeseries)
        throw(DomainError("All time series must be of the same length as number of timesteps in model."))
    end
    true
end


# --- Nodes ---

"""
    abstract type AbstractNode end

Abstract type for nodes.
"""
abstract type AbstractNode end

"""
    const Name = String

Type alias for String to ease readability of code.
"""
const Name = String


"""
    struct EnergyNode <: AbstractNode
        name::Name
        external_flow::TimeSeries
    end

Type for modeling energy nodes.
"""
struct EnergyNode <: AbstractNode
    name::Name
    external_flow::TimeSeries
end


"""
    function energy_node(name::Name, external_flow::TimeSeries, S::Scenarios, T::TimeSteps)

Construct EnergyNode with given inflow or demand given as external flow time series.
"""
function energy_node(name::Name, external_flow::TimeSeries, S::Scenarios, T::TimeSteps)
    validate_time_series(external_flow, S, T)
    EnergyNode(name, external_flow)
end


"""
    struct StorageNode <: AbstractNode
        name::Name
        in_flow_max::Float64
        out_flow_max::Float64
        state_max::Float64
        state_loss::Float64
        external_flow::TimeSeries
        initial_state::Float64
    end


Type for modeling storage nodes.
"""
struct StorageNode <: AbstractNode
    name::Name
    in_flow_max::Float64
    out_flow_max::Float64
    state_max::Float64
    state_loss::Float64
    external_flow::TimeSeries
    initial_state::Float64
end

"""
    function storage_node(name::Name, in_flow_max::Number, out_flow_max::Number, 
        state_max::Number, state_loss::Number, 
        external_flow::TimeSeries, S::Scenarios, T::TimeSteps, initial_state::Number=0) 

Construct StorageNode with given parameters.
"""
function storage_node(name::Name, in_flow_max::Number, out_flow_max::Number, 
    state_max::Number, state_loss::Number, 
    external_flow::TimeSeries, S::Scenarios, T::TimeSteps, initial_state::Number=0)    

    validate_time_series(external_flow, S, T)
    if !(0 <= state_loss <= 1)
        throw(DomainError("State loss must be between 0 and 1."))
    elseif !(initial_state <= state_max)
        throw(DomainError("Initial state cannot exceed maximum state."))
    end  
    StorageNode(name, in_flow_max, out_flow_max, state_max, state_loss, external_flow, initial_state)
end


"""
    struct CommodityNode <: AbstractNode
        name::Name
        cost::TimeSeries
    end


Type for modeling commodity nodes.
"""
struct CommodityNode <: AbstractNode
    name::Name
    cost::TimeSeries
end


"""
    function commodity_node(name::Name, cost::TimeSeries, S::Scenarios, T::TimeSteps)

Construct CommodityNode with given cost time series.
"""
function commodity_node(name::Name, cost::TimeSeries, S::Scenarios, T::TimeSteps)
    validate_time_series(cost, S, T)
    CommodityNode(name, cost)
end

"""
    struct MarketNode <: AbstractNode
        name::Name
        price::TimeSeries
    end


Type for modeling market nodes.
"""
struct MarketNode <: AbstractNode
    name::Name
    price::TimeSeries
end

"""
    function market_node(name::Name, price::TimeSeries, S::Scenarios, T::TimeSteps)

Construct MarketNode with given market price estimate time series.
"""
function market_node(name::Name, price::TimeSeries, S::Scenarios, T::TimeSteps)
    validate_time_series(price, S, T)
    MarketNode(name, price)
end



# --- Processes ---
"""
    abstract type AbstractProcess end

Abstract type for processes.
"""
abstract type AbstractProcess end


"""
    struct FlexibleProcess <: AbstractProcess
        name::Name
        efficiency::TimeSeries
        cf::TimeSeries
        ramp_rate::Float64
    end


Type for modeling flexible processes.
"""
struct FlexibleProcess <: AbstractProcess
    name::Name
    efficiency::TimeSeries
    cf::TimeSeries
    ramp_rate::Float64
end

"""
    function flexible_process(name::Name, efficiency::TimeSeries, cf::TimeSeries, S::Scenarios, T::TimeSteps, ramp_rate::Number)

Construct FlexibleProcess with given efficiency and capacity factor time series and ramp rate. 
"""
function flexible_process(name::Name, efficiency::TimeSeries, cf::TimeSeries, S::Scenarios, T::TimeSteps, ramp_rate::Number)
    validate_time_series(efficiency, S, T)
    validate_time_series(cf, S, T)
    if !all(0 <= efficiency[s][t] <= 1 for s in S, t in T)
        throw(DomainError("Efficiency values must be between 0 and 1."))
    elseif !all(0 <= cf[s][t] <= 1 for s in S, t in T)
        throw(DomainError("Capacity factor values must be between 0 and 1."))
    elseif !(0 <= ramp_rate <= 1)
        throw(DomainError("Ramp rate value must be between 0 and 1."))
    end

    FlexibleProcess(name, efficiency, cf, ramp_rate)
end

"""
    struct VREProcess <: AbstractProcess
        name::Name
        cf::TimeSeries
    end


Type for modeling VRE processes.
"""
struct VREProcess <: AbstractProcess
    name::Name
    cf::TimeSeries
end

"""
    function vre_process(name::Name, cf::TimeSeries, S::Scenarios, T::TimeSteps)

Construct VREProcess with given capacity factor time series.
"""
function vre_process(name::Name, cf::TimeSeries, S::Scenarios, T::TimeSteps)
    validate_time_series(cf, S, T)

    if !all(0 <= cf[s][t] <= 1 for s in S, t in T)
        throw(DomainError("Capacity factor values must be between 0 and 1."))
    end

    VREProcess(name, cf)
end


"""
    struct OnlineProcess <: AbstractProcess
        name::Name
        efficiency::TimeSeries
        cf::TimeSeries
        min_load::Float64
        min_online::Int
        min_offline::Int
        ramp_rate::Float64
        start_cost::Float64
        initial_status::Int
    end

Type for representing online processes.
"""
struct OnlineProcess <: AbstractProcess
    name::Name
    efficiency::TimeSeries
    cf::TimeSeries
    min_load::Float64
    min_online::Int
    min_offline::Int
    ramp_rate::Float64
    start_cost::Float64
    initial_status::Int
end

"""
    function online_process(name::Name, efficiency::TimeSeries, cf::TimeSeries, S::Scenarios, T::TimeSteps,
        min_load::Number, min_online::Int, min_offline::Int, ramp_rate::Number,
        start_cost::Number, initial_status::Int=1)

Construct OnlineProcess with given parameters.
"""
function online_process(name::Name, efficiency::TimeSeries, cf::TimeSeries, S::Scenarios, T::TimeSteps,
    min_load::Number, min_online::Int, min_offline::Int, ramp_rate::Number,
    start_cost::Number, initial_status::Int=1)
    
    validate_time_series(efficiency, S, T)
    validate_time_series(cf, S, T)

    if !all(0 <= efficiency[s][t] <= 1 for s in S, t in T)
        throw(DomainError("Efficiency values must be between 0 and 1."))
    elseif !all(0 <= cf[s][t] <= 1 for s in S, t in T)
        throw(DomainError("Capacity factor values must be between 0 and 1."))
    elseif !(0 <= min_load <= 1)
        throw(DomainError("Minimum load must be between 0 and 1."))
    elseif !(0 <= min_online && 0 <= min_offline)
        throw(DomainError("Minimum online and offline times must be nonnegative."))
    elseif !(0 <= ramp_rate <= 1)
        throw(DomainError("Ramp rate value must be between 0 and 1."))
    elseif !(0 == initial_status || 1 == initial_status)
        throw(DomainError("Initial status must be 0 or 1."))
    end

    OnlineProcess(name, efficiency, cf, min_load, min_online, min_offline, ramp_rate, start_cost, initial_status)
end



# --- Flow ---
"""
    abstract type AbstractFlow end

Abstract type for flows.
"""
abstract type AbstractFlow end


"""
    struct ProcessFlow <: AbstractFlow
        source::Name
        sink::Name
        capacity::Float64
        VOM_cost::Float64
    end

Type for modeling flows connecting node-process or process-node pairs. 
"""
struct ProcessFlow <: AbstractFlow
    source::Name
    sink::Name
    capacity::Float64
    VOM_cost::Float64
end


"""
    function process_flow(source::Name, sink::Name, 
        capacity::Number, VOM_cost::Number)

Construct ProcessFlow between source and sink with a capacity and VOM costs given as parameters.
"""
function process_flow(source::Name, sink::Name, 
    capacity::Number, VOM_cost::Number)

    if source == sink
        throw(DomainError("The source and sink of a flow cannot be the same."))
    elseif capacity < 0
        throw(DomainError("The capacity of a flow must be nonnegative."))
    end

    ProcessFlow(source, sink, capacity, VOM_cost)
end

"""
    struct TransferFlow <: AbstractFlow
        source::Name
        sink::Name
    end

Type for modeling transfer flows, which move energy between two nodes.
"""
struct TransferFlow <: AbstractFlow
    source::Name
    sink::Name
end


"""
    function transfer_flow(source::Name, sink::Name)

Construct TransferFlow between source and sink.
"""
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

Type for modeling market flows, which transfer energy between a market node and another node.
"""
struct MarketFlow <: AbstractFlow
    source::Name
    sink::Name
end

"""
    function market_flow(market::Name, node::Name)

Return two MarketFlow structures in order of (bought energy, sold energy) between the market node and other node.
"""
function market_flow(market::Name, node::Name)
    if market == node
        throw(DomainError("The source and sink of a flow cannot be the same."))
    end

    MarketFlow(market, node), MarketFlow(node, market)
end


# --- ModelStructure ---


"""
    mutable struct ModelStructure
        S::Scenarios
        T::TimeSteps
        energy_nodes::Vector{EnergyNode}
        storage_nodes::Vector{StorageNode}
        commodity_nodes::Vector{CommodityNode}
        market_nodes::Vector{MarketNode}
        flexible_processes::Vector{FlexibleProcess}
        vre_processes::Vector{VREProcess}
        online_processes::Vector{OnlineProcess}
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
    scenario_probabilities::Vector{Float64}
    energy_nodes::Vector{EnergyNode}
    storage_nodes::Vector{StorageNode}
    commodity_nodes::Vector{CommodityNode}
    market_nodes::Vector{MarketNode}
    flexible_processes::Vector{FlexibleProcess}
    vre_processes::Vector{VREProcess}
    online_processes::Vector{OnlineProcess}
    process_flows::Vector{ProcessFlow}
    transfer_flows::Vector{TransferFlow}
    market_flows::Vector{MarketFlow}

    function ModelStructure(S::Scenarios, T::TimeSteps, scenario_probabilities::Vector{Float64})
        if isapprox(sum(scenario_probabilities), 1.0) && length(scenario_probabilities) == length(S)
            new(S, T, scenario_probabilities, [], [], [], [], [], [], [], [], [], [])
        else
            throw(DomainError("Scenario probabilities must sum to 1.0 and there must be a probability for each scenario."))
        end
    end
end

# --- Filling ModelStructure ---
"""
    function get_names(structure::ModelStructure; nodes::Bool=false, processes::Bool=false)

Return vector of nodes' and/or processes' names.

# Fields
- `structure::ModelStructure`: Structure of the house company's energy system. 
- `nodes::Bool=false`: Set true if names of nodes should be returned.
- `processes::Bool=false`: Set true if names of processes should be returned.

"""
function get_names(structure::ModelStructure; nodes::Bool=false, processes::Bool=false)
    all_names = []

    if nodes
        push!(all_names, map(n -> n.name, structure.energy_nodes)...)
        push!(all_names, map(n -> n.name, structure.storage_nodes)...)
        push!(all_names, map(n -> n.name, structure.commodity_nodes)...)
        push!(all_names, map(n -> n.name, structure.market_nodes)...)
    end

    if processes
        push!(all_names, map(n -> n.name, structure.flexible_processes)...)
        push!(all_names, map(n -> n.name, structure.vre_processes)...)
        push!(all_names, map(n -> n.name, structure.online_processes)...)
    end
    return all_names
end


"""
    function get_flows(structure::ModelStructure; names=false)

Return flows (of type AbstractFlow) in structure as a vector.

# Fields
- `structure::ModelStructure`: Structure of the house company's energy system. 
- `names::Bool=false`: Set true if only names of (source, sink) pairs should be returned.

"""
function get_flows(structure::ModelStructure; names::Bool=false)
    
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

"""
    function add_nodes!(structure::ModelStructure, nodes::Vector{N}) where N<:AbstractNode

Add nodes to model structure into the correct fields according to node type.
"""
function add_nodes!(structure::ModelStructure, nodes::Vector{N}) where N<:AbstractNode
    for n in nodes
        
        names = get_names(structure, nodes=true, processes=true)
        if n.name in names
            throw(DomainError("Name $(n.name) is not unique. Name must be unique."))
        end

        if isa(n, EnergyNode)
            push!(structure.energy_nodes, n)

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

"""
    function add_processes!(structure::ModelStructure, processes::Vector{N}) where N<:AbstractProcess

Add processes to model structure into the correct fields according to process type.
"""
function add_processes!(structure::ModelStructure, processes::Vector{N}) where N<:AbstractProcess
    for p in processes
        
        names = get_names(structure, nodes=true, processes=true)
        if p.name in names
            throw(DomainError("Name $p.name is not unique. Name must be unique."))
        end

        if isa(p, FlexibleProcess)
            push!(structure.flexible_processes, p)

        elseif isa(p, VREProcess)
            push!(structure.vre_processes, p)

        elseif isa(p, OnlineProcess)
            push!(structure.online_processes, p)

        else
            throw(DomainError("Process $p type is not recognised.")) 
        end
    end
end

"""
    function add_flows!(structure::ModelStructure, flows::Vector{N}) where N<:AbstractFlow

Add flows to model structure into the correct fields according to flow type.
"""
function add_flows!(structure::ModelStructure, flows::Vector{N}) where N<:AbstractFlow
    names = get_names(structure, nodes=true, processes=true)
    nodes = get_names(structure, nodes=true)
    processes = get_names(structure, processes=true)
    market_nodes = (n.name for n in structure.market_nodes)
    commodity_nodes = (n.name for n in structure.commodity_nodes)
    vre_processes = (p.name for p in structure.vre_processes)
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
        
        elseif f.sink in vre_processes
            throw(DomainError("A VRE process cannot be a sink. Issue in ($(f.source) -> $(f.sink))"))

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

"""
    function validate_network(structure::ModelStructure)

Validate that all processes and nodes are connected to some other node or process in the model.
"""
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