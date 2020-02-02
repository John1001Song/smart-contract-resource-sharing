# Resource Sharing Project
We implement a smart contract about P2P computing resource sharing. 

# Design

1. Three constructors: Contract, Consumer and Provider  
Contract:  provider_map, p_index_array  
Consumer:  ID, name, budget, time_cost  
Provider:  ID, name, target, start, end   

2. Contract functions:
* Contract: add_Provider, add_Consumer, match  
* Consumer: request  
* Provider: register  

3. Simulation
Similar to the js file about vote, we need to simulate consumers send request and providers register themselves.   
Consumer:  
Provider:  

# Evaluation
1. Engagement Rate
Assume all consumers' requirements are met with providers. Evaluate how much is the percentage of consumers can find a provider.  
About user number, Consumer vs Provider:  
10 vs 10  
20 vs 20  
50 vs 50
100 vs 100  

2. Speed
Assume both consumers and providers are ready, and always the number of consumer is less than the number of provider. Speed tests how much time a consumer will be matched with a provider in average when users size increases from 10 to 100. Speed = consumer engaged time - consumer request sent time

3. Gas/Eth Consumption
Graph the average gas or Eth consumption of each engagement when user size increases from 10 to 100.

# Code Design
## Remove expired providers
1. Check expired providers in mode "min_latency".
2. If a provider is expired, delete it in providerMap, but keep all provider indices.
3. When iterating provider indices, remove a provider index if its end is 0(which means that provider is expired). 