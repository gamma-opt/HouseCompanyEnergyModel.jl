using Revise
using JuMP
using PredicerTestVersion

S = scenarios(2)
T = time_steps(4)

PV_cf = [[0.85, 0.90, 0.95, 1.0],[0.4, 0.8, 0.5, 0.55]]
PV = cf_unit_process("PV", PV_cf, S, T)

ELC_demand = [[18.3, 19.1, 18.1, 17.9],[23.2, 24.3, 22.9, 22.7]]
ELC = plain_node("ELC", ELC_demand, S, T)

NPE_price = [[13.22, 13.22, 13.25, 13.01],[13.23, 13.23, 13.23, 13.01]] 
NPE = market_node("NPE", NPE_price, S, T)

# Flow from PV to ELC. Notice ramp_rate = 1 because no ramp limit for PV energy.
PV_capacity = [fill(19.0, length(T)),fill(19.0, length(T))]
PV_generation = process_flow("PV", "ELC", PV_capacity, S, T, 0.0, 1.0)

# Flows to and from ELC to NPE
ELC_bought, ELC_sold = market_flow("NPE", "ELC")

structure = ModelStructure(S, T, [0.5, 0.5])

add_nodes!(structure, [NPE, ELC])
add_processes!(structure, [PV])
add_flows!(structure, [PV_generation, ELC_bought, ELC_sold])

validate_network(structure)

# -- Initialise JuMP model
model = Model()

# Variable generation
f  = flow_variables(model, structure)
shortage, surplus = shortage_surplus_variables(model, structure)

# Constraint generation

balance = state_balance_constraints(model, structure, f, shortage, surplus)

flow_bounds = process_flow_bound_constraints(model, structure, f)

c10 = market_bidding_constraints(model, structure, f)