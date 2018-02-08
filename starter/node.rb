require 'socket'
require_relative 'listener'
require_relative 'messege_handler'
require_relative 'packet'

$port = nil
$hostname = nil
$flood_map_changed = false
$sequence_number = 0

$messege_handler

$timeout_map = {}
$ping_queue = {}

#map of SEQ/ACK numbers 
	# => Time

#every node
$routing_table = {}
# => [DEST_NODE]
	# => [SRC_NODE]	source node name
	# => [NEXT_NODE]	next ndoe name in path node name
	# => [DIST]	distance from source to destination

#every node
$node_socket_info = {}
# => [node name]
	# => [PORT]
	# => [SEQ]

$neighbors = []
$flood_map = {}

$data_delim = " "
$connections = []
# --------------------- Part 1 --------------------- # 

def edgeb(cmd) # [ SRCIP ] [ DSTIP ] [ DST ]
	puts "NODE: edgeb(#{cmd})"

	src_ip = cmd[0]
	dest_ip = cmd[1]
	dest_node = cmd[2]

	$neighbors << dest_node


	if $flood_map[$hostname].nil?
		$flood_map[$hostname] = {}
	end
	$flood_map[$hostname][dest_node] = 1


	$routing_table[dest_node] = {}
	
	$routing_table[dest_node]["NEXT_NODE"] = dest_node
	$routing_table[dest_node]["DIST"] = 1

	$node_socket_info[dest_node]["IP"] = dest_ip
	dest_port = $node_socket_info[dest_node]["PORT"]
	
	

	data = 	$hostname + $data_delim \
			+ src_ip + $data_delim \
			+ $port

	packet = Packet.new
	packet.set_type("EDGEB")
	packet.set_data(data)
	packet.set_origin_node($hostname)

	packet.set_dest_node(dest_node)

	$messege_handler.send_msg(packet)
end

def dumptable(cmd) # SRC, DST, nextHop, dist
	
	begin
	filename = cmd.first
	
	out_file = File.open(filename, "w")

	
		$routing_table.each do |dst, dst_hash|

			next if dst_hash.nil?
		
			src = $hostname
			nxt = dst_hash["NEXT_NODE"]
			dist = dst_hash["DIST"]
		
			output = "#{src},#{dst},#{nxt},#{dist}\n"
		
			out_file.write(output)
		end

	rescue Exception => e
		puts "EXCEPTION => #{e}"
	end
end

def shutdown(cmd)
	sleep 0.5
	$server.close unless $server.nil?
	STDERR.flush
	STDOUT.flush
	exit(0)
end

#---------------------PART2---------------------------

def edgeu(cmd)
	begin
	puts "EDGE U: #{cmd}"
	dst = cmd.first
	new_cost = cmd.last.to_i

	diff_cost = new_cost - $routing_table[dst]["DIST"] 

	$routing_table.each do |dest, dest_hash|
		next if dest_hash.nil?

		if dest_hash["NEXT_NODE"] == dst
			$routing_table[dest]["DIST"] += diff_cost
		end
	end

	$flood_map[$hostname][dst] = new_cost
	
	CommandHandler.dijkstra
	
	rescue Exception => e
		puts "EDGEU EXCEPTION => #{e}"
	end 
end

def status
	puts "Running STATUS"
	nbrs = $neighbors.sort.join(",")

	str = "Name: <#{$hostname}>"
	str += "Port: <#{$port}>"
	str += "Neighbors: <nbrs>"

	puts str
	return str
end

def edged(cmd)
	puts "Running EDGED"
	to_delete = cmd.first

	return unless $neighbors.include? to_delete
	$neighbors.delete to_delete

	$flood_map.each do |src, hash|
		if src == $hostname
			hash.each do |dest, cost|
				if dest == to_delete
					$flood_map[src].delete(dest)
				end
			end
		end
	end

	CommandHandler.dijkstra
end

# --------------------- Part 3 --------------------- # 
def sendmsg(cmd)

	dest_node = cmd[0]
	message = cmd[1..-1].join(' ')

	packet = Packet.new
	packet.set_type("SENDMSG")
	packet.set_data(message)
	packet.set_origin_node($hostname)

	packet.set_dest_node(dest_node)
	
	$messege_handler.send_msg(packet)
end

def ping(cmd)
	
	dest_node = cmd[0]
	numpings = cmd[1].to_i
	delay = cmd[2].to_i

	packet = Packet.new
	packet.set_type("PING")
	packet.set_origin_node($hostname)
	packet.set_dest_node(dest_node)

	0.upto(numpings - 1).each do |ping_seq|
		packet.set_data(ping_seq.to_s)
		$ping_queue[$clock + (ping_seq * delay)] = packet.dup
	end
end

def traceroute(cmd)
	STDOUT.puts "TRACEROUTE: running"
	dest_node = cmd.first

	trace_packet = Packet.new
	trace_packet.set_type("TRACE")
	trace_packet.set_origin_node($hostname)
	trace_packet.set_dest_node(dest_node)
	trace_packet.set_data($clock.to_s)

	$messege_handler.send_msg(trace_packet)
	puts "\t0 #{$hostname} 0"

end


# do main loop here.... 
def main()

	while(line = STDIN.gets())
		puts "\t\t#{line.chomp} @#{$clock}"
		line = line.strip()
		arr = line.split(' ')
		cmd = arr[0]
		args = arr[1..-1]
		case cmd
		when "EDGEB"; edgeb(args)
		when "EDGED"; edged(args)
		when "EDGEU"; edgeu(args)
		when "DUMPTABLE"; dumptable(args)
		when "SHUTDOWN"; shutdown(args)
		when "STATUS"; status()
		when "SENDMSG"; sendmsg(args)
		when "PING"; ping(args)
		when "TRACEROUTE"; traceroute(args)
		when "FTP"; ftp(args);
		when "CIRCUIT"; circuit(args);
		else STDERR.puts "ERROR: INVALID COMMAND \"#{cmd}\""
		end
	end
end

def send_flood_msg
	begin
	
	data = ""
	str = ""
	return if $neighbors.empty?

	# create data packet for all neighbors
	$neighbors.each do |neighbor|
		str = ""
		neighbor_info = $routing_table[neighbor]

		if neighbor_info.nil?
			next
		end

		next if neighbor_info["NEXT_NODE"].nil?
		next if neighbor_info["DIST"].nil?

		neighbor_dist = neighbor_info["DIST"]

		str = "#{neighbor} #{neighbor_dist};"
		data += str
	end

	data = data[0..-2]

	# send flood to all neighbors
	$neighbors.each do |neighbor|
		#still have to check seq numbers before sending
		p = Packet.new
		p.set_type("FLOOD")
		p.set_origin_node($hostname)
		
		p.set_data(data)
		p.set_dest_node(neighbor)

		$messege_handler.send_msg(p)
	end
	rescue Exception => e
		puts "send_flood_msg() EXCEPTION => #{e}"
	end
end

def setup(hostname, port, nodes, config)
	puts "hostname #{hostname} port #{port}"

	$hostname = hostname
	$port = port

	File.open( nodes ).each do |line|
		arr = line.strip().split(",")

		#won't store our own node here
		next if hostname == arr[0]
		
		$node_socket_info[arr[0]] = {}
		$node_socket_info[arr[0]]["PORT"] = arr[1]
		$node_socket_info[arr[0]]["SEQIN"] = -1 
	end

	File.open(config).each do |line|
		arr = line.strip.split("=")
		case arr.first.to_s
		when "updateInterval"; $update_interval = arr.last.to_i
		when "maxPayload"; $max_payload = arr.last.to_i
		when "pingTimeout"; $ping_timeout = arr.last.to_i
		end
	end

	@l = Listener.new port
	
	thread_listener = Thread.new do
		@l.start
	end

	$messege_handler = MessegeHandler.new port#, @l

	thread_messege_handler = Thread.new do
		$messege_handler.start
	end

	
	@time = Time.new
	$clock = Time.now().to_f
	puts "clock made"
	$clock = 0.0
	$clock_lock = Mutex.new
	$tick = 0.01
	@tolerance = 0.001

	t = Thread.new do
		while(true)
		
			clock_diff = ($clock % $update_interval).abs
			
			if (clock_diff < @tolerance) or ($update_interval - clock_diff < @tolerance)
				send_flood_msg
			end

	   		sleep($tick)
			$clock_lock.synchronize{
	   		
				$clock += $tick
			}
		end
	end

	main()
end

setup(ARGV[0], ARGV[1], ARGV[2], ARGV[3])