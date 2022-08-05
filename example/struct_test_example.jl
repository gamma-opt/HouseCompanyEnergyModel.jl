using Revise; using JuMP; using Gurobi; using PredicerTestVersion

include("../test/runtests.jl")

# Model initialisation
model = Model()

# Variable generation
f  = flow_variables(model, structure)
s = state_variables(model, structure)
shortage, surplus = shortage_surplus_variables(model, structure)
start, stop, online = start_stop_online_variables(model, structure)

# Constraint generation
c2,c3 = charging_discharging_constraints(model, s, structure)
c4 = process_flow_bound_constraints(model, f, online, structure)
c5 = process_ramp_rate_constraints(model, f, start, stop, structure)
c6 = process_efficiency_constraints(model, f, structure)
c7, c8, c9 = online_functionality_constraints(model, start, stop, online, structure)
c10 = market_bidding_constraints(model, f, structure)


optimizer = optimizer_with_attributes(
    () -> Gurobi.Optimizer(Gurobi.Env()),
    "IntFeasTol"      => 1e-6,
)
set_optimizer(model, optimizer)

optimize!(model)