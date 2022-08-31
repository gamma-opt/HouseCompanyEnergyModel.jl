using JuMP
using HouseCompanyEnergyModel
using Gurobi


# -- Model set up --
S = scenarios(2)
T = time_steps(4)

PV_cf = [[1.0, 0.90, 0.90, 1.0],[0.4, 0.8, 0.5, 0.6]]
PV = vre_process("PV", PV_cf, S, T)

ELC_demand = -1*[[19, 19, 18, 17],[23, 24, 22, 22]]
ELC = energy_node("ELC", ELC_demand, S, T)

NPE_price = [[13, 13, 13, 13],[13, 13, 14, 12]] 
NPE = market_node("NPE", NPE_price, S, T)

# Flow from PV to ELC
PV_generation = process_flow("PV", "ELC", 20, 0.0)

# Flows to and from ELC to NPE
ELC_bought, ELC_sold = market_flow("NPE", "ELC")

structure = ModelStructure(S, T, [0.5, 0.5])

add_nodes!(structure, [NPE, ELC])
add_processes!(structure, [PV])
add_flows!(structure, [PV_generation, ELC_bought, ELC_sold])

validate_network(structure)



# -- Initialise JuMP model --
model = Model()

# Variable generation
f  = flow_variables(model, structure)
shortage, surplus = shortage_surplus_variables(model, structure)

# Constraint generation
balance = state_balance_constraints(model, structure, f, shortage, surplus)

cf_bounds = cf_flow_constraints(model, structure, f)

objective = declare_objective(model, structure, f, shortage, surplus, 50.0)

optimizer = optimizer_with_attributes(
    () -> Gurobi.Optimizer(Gurobi.Env()),
    "IntFeasTol"      => 1e-6,
)
set_optimizer(model, optimizer)


optimize!(model)

if any(value(i) != 0 for i in values(shortage)) || any(value(i) != 0 for i in values(surplus))
    throw(DomainError("Slack variables nonzero!!!"))
end  

solution_summary(model, verbose=true)