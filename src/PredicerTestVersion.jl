module PredicerTestVersion

include("structures.jl")
include("variables.jl")
include("constraints.jl")
include("objective.jl")

export TimeSteps,
    time_steps,
    Scenarios,
    scenarios,
    TimeSeries,
    validate_time_series,

    AbstractNode,
    EnergyNode,
    energy_node,
    StorageNode,
    storage_node,
    CommodityNode,
    commodity_node,
    MarketNode,
    market_node,

    AbstractProcess,
    SpinningProcess,
    spinning_process,
    VREProcess,
    vre_process,
    OnlineProcess,
    online_process,

    AbstractFlow,
    ProcessFlow,
    process_flow,
    TransferFlow,
    transfer_flow,
    MarketFlow,
    market_flow,

    ModelStructure,

    get_names,
    get_flows,
    add_nodes!,
    add_processes!,
    add_flows!,
    validate_network,

    FlowTuple,
    flow_variables,
    NodeTuple,
    state_variables,
    shortage_surplus_variables,
    ProcessTuple,
    start_stop_online_variables,

    charging_discharging_constraints,
    state_balance_constraints,
    process_flow_constraints,
    process_ramp_rate_constraints,
    process_efficiency_constraints,
    online_functionality_constraints,
    market_bidding_constraints,

    declare_objective
end 
