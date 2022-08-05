module PredicerTestVersion

include("structures.jl")
include("variables.jl")
include("constraints.jl")

export TimeSteps,
    time_steps,
    Scenarios,
    scenarios,
    TimeSeries,
    validate_time_series,

    AbstractNode,
    PlainNode,
    plain_node,
    StorageNode,
    storage_node,
    CommodityNode,
    commodity_node,
    MarketNode,
    market_node,

    AbstractProcess,
    PlainUnitProcess,
    plain_unit_process,
    CFUnitProcess,
    cf_unit_process,
    OnlineUnitProcess,
    online_unit_process,

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
    process_flow_bound_constraints,
    process_ramp_rate_constraints,
    process_efficiency_constraints,
    online_functionality_constraints,
    market_bidding_constraints
end 
