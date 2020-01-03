# Resource Sharing Project
We implement a smart contract about P2P computing resource sharing. 

# Design

1. Three constructors: Contract, Consumer and Provider  
Contract:  provider_map, p_index_array  
Consumer:  ID, name, budget, time_cost  
Provider:  ID, name, target, start, end   

2. Contract functions:
⋅⋅* Contract: add_Provider, add_Consumer, match, 
⋅⋅* Consumer: request 
⋅⋅* Provider: register

