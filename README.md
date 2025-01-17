# Team members

- Bala Surya Krishna Vankayala
- Mohan Kalyan Veeraghanta

# How to run this project

- run the command ponyc to compile the files.
- run the command ".\project3.exe <number of nodes> <num of req>"
- for example: .\project3 20 30

# What is working

This project simulates a Chord Distributed Hash Table (DHT), implementing key operations such as node lookup, finger table generation, and handling requests across a dynamically connected network of nodes. Chord is designed for efficient key-based routing in a distributed system, supporting network scalability.

- Node Initialization: Initializes a given number of nodes in the Chord network.
- Node Connections: Each node connects to the network and establishes links with other nodes through a finger table.
- Request Handling: Nodes process requests for specific keys and maintain a count of hops taken to locate each key.
- Random Node Selection: Nodes randomly select other nodes for connections and request routing.
- Successor Lookup: Nodes locate the successor for given keys based on their finger tables.
- Statistics Logging: Logs total requests, total hops, and the average hops per request to evaluate network efficiency.

# What is the largest network you managed to deal with

The largest network we successfully managed with our Chord implementation consisted of 100,000 nodes (peers), each making 500 requests in the peer-to-peer system. Each node sent one request per second, allowing us to observe the scalability and efficiency of the Chord protocol under high request loads. This setup showed that, despite a large number of peers and requests, the average hop count stayed near the expected log₂(N) value, confirming the efficiency of the finger table optimization.