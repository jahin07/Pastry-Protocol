# Project3

**Pastry Protocol**

**Group Members: 
Jahin Majumdar(UFID 69139840)
Spandita Gujrati (UFID 81858145)**

## 1. What is working
We have used base 16 (hexadecimal) and 128 bits for our node_id
100% convergence is being achieved. To ensure this and so that no loss of messages occur, an additonal check has been put. This additional check detects loop and as soon as it is detected, it selects a new path to forward the message. 
The average number of hops are calculated as: total_hops / (no_of_nodes * no_of_requests). An upper bound of O(log n) hops is achieved.

## 2. What is the largest network you managed to deal with
10000 nodes with 10 requests
Average no of hops = 3.01

### Note about output: We have put a 10 second :timer.sleep to ensure all the messages reach the destination

## Output
Average Hops
...