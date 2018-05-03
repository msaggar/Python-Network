# Python Network
Overlay Routing & Distributed Transaction Processing

In this project, you will apply what you have learned throughout the semester to build an overlay
routing system that uses Link State routing to pass messages between arbitrary nodes.
Overlay routing is routing that happens at the application layer. The application layer
processes on a given node, connect to application layer processes on other nodes to build routing
tables and pass messages.

Your task is to implement an application layer protocol using the fact that nodes know how to
communicate with their direct neighbors. Using this simple fact, you will enable communication
between arbitrary nodes. Your code will run at the application layer. Instances applications running
on dierent nodes will be able to communicate with instances running on other nodes. Put another
way, instances of your application will be able to communicate across nodes.

# Project-Writeup

Our project is structured across five files:
1. **node.rb**: Parses input from command line and runs appropriate commands on input.
The clock, message handler, and listener are each running in there own thread so that
they are non blocking.
2. **message_handler.rb**: Adds messages to an output_queue. Dequeues a message one
at a time and writes them to their destination nodes. Will fragment nodes on queue if
they are greater than max queue size.
3. **listener.rb**: Reads a message from the socket and passes it off to the command handler
based on the type of the packet. Will support assembling fragmented packets if needed.
4. **command_handler.rb**: Process a packet and runs commands on that packet based on
the packet type. May forward packets to new nodes, add information to routing tables,
send ACK’s and more.
5. **packet.rb**: maintains a packet structure that is used for reading and writing. All packets
track origin, destination, type, seq_num, ttl/hop count, length, and a data field that is specific to the type of packet. Id and frag are field for fragmenting
Decisions:
1. **Flooding**: Flood packets are created in a specific way. They broadcast the cost of a
node to all of its neighbours. This list of tuples ​(neighbour, cost)​ is sent as a flood message to the neighbours and each neighbour maintains a flood map of cost to its neighbours. When costs change, we know the network topology changes and run dijkstra. Dijkstra is also run when updating and deleting without having to flood because we know the command will update the map.
2. **Sequence Numbers**: Each node maintains its most recent sequence number and stamps that on any outgoing packets. We also maintain a map that maps nodename to sequence number. If the origin node in a packet is less than the sequence number in the map, it is rejected. Otherwise the map is updated with the new sequence number cost.
3. **ACKs**: We maintain a timeout for ACKs for each node that maps sequence numbers to a timestamp. When sending a message with sequence number “X”, we expect to receive an a packet back where ACK=”X” and SEQ=”Y”. We can then index this map to determine if the time of the packet received to determine whether the message has timed out by comparing it to the timestamp in the map.
4. **Fragmentation**: We maintain an id and frag field. The id tells us which packets are to be assembled and frag field is a boolean value set to true/false. We assemble fragment at every node because it was faster to implement and we were on a time constraint. It is most likely more efficient to assemble at the destination node.
