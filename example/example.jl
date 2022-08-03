using Revise; using JuMP; using PredicerTestVersion

include("../test/runtests.jl")

# Model initialisation
m = Model()

# Variable generation
f  = flow_variables(m, structure)
s = state_variables(m, structure)
shortage, surplus = shortage_surplus_variables(m, structure)
start, stop, online = start_stop_online_variables(m, structure)

# Constraint generation
c1 = initial_state_constraints(m, s, structure)
c2,c3 = charging_discharging_constraints(m, s, structure)
c4 = process_flow_bound_constraints(m, f, online, structure)
c5 = process_ramp_rate_constraints(m, f, start, stop, structure)
c6 = process_efficiency_constraints(m, f, structure)
c7, c8, c9 = online_functionality_constraints(m, start, stop, online, structure)
c10 = market_bidding_constraints(m, f, structure)