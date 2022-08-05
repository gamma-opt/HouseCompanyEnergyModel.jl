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
c1,c2 = charging_discharging_constraints(model, structure, s)
c3 = state_balance_constraints(model, structure, f, s, shortage, surplus)
c4 = process_flow_bound_constraints(model, structure, f, online)
c5 = process_ramp_rate_constraints(model, structure, f, start, stop)
c6 = process_efficiency_constraints(model, structure, f)
c7, c8, c9 = online_functionality_constraints(model, structure, start, stop, online)
c10 = market_bidding_constraints(model, structure, f)


optimizer = optimizer_with_attributes(
    () -> Gurobi.Optimizer(Gurobi.Env()),
    "IntFeasTol"      => 1e-6,
)
set_optimizer(model, optimizer)

optimize!(model)