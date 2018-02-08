class CommandHandler


	def initialize(packet)
		
		@type = packet.get_type
		@origin_node = packet.get_origin_node

		@dest_node = packet.get_dest_node
		@seq = packet.get_seq.to_i
		@ack_num = packet.get_ack_number
		@data = packet.get_data
		@ttl = packet.get_ttl
		@packet = packet

		case @type
		when "ACK"; receive_ack
		when "FLOOD"; receive_flood
		when "EDGEB"; receive_edgeb
		when "SENDMSG"; receive_sendmsg
		when "PING"; receive_ping
		when "TRACE"; receive_trace
		else puts "ERROR: INVALID COMMAND \"#{@type}\""
		end
	end

	def receive_trace
		puts "Recieved TRACE packet at host #{$hostname}: #{@packet}"

		ack_packet = Packet.new
		ack_packet.set_type("ACK")
		ack_packet.set_origin_node($hostname)
		ack_packet.set_dest_node(@origin_node)
		ack_packet.set_ack_number(@seq)
		ack_packet.set_data($clock.to_s)

		if @dest_node == $hostname
			$messege_handler.send_msg(ack_packet)
		else 
			$messege_handler.send_msg(ack_packet)
			$messege_handler.send_msg(@packet)
		end

	end

	def receive_ping
		puts "COMMAND_HANDLER: receive_sendmsg()"
		if @dest_node == $hostname
			puts "PING: [#{@origin_node}]-->[#{@dest_node}]"
			ack_packet = Packet.new
			ack_packet.set_type("ACK")
			ack_packet.set_origin_node($hostname)
			ack_packet.set_dest_node(@origin_node)
			ack_packet.set_ack_number(@seq)
			ack_packet.set_data(@data)
			$messege_handler.send_msg(ack_packet)
		else
			$messege_handler.send_msg(@packet)
		end
	end

	def receive_sendmsg
		puts "COMMAND_HANDLER: receive_sendmsg()"


		if @dest_node == $hostname
			puts "SENDMSG: #{@origin_node} --> #{@data}"##{@dest_node}"
			ack_packet = Packet.new
			ack_packet.set_type("ACK")
			ack_packet.set_origin_node($hostname)
			ack_packet.set_dest_node(@origin_node)
			ack_packet.set_ack_number(@seq)
			$messege_handler.send_msg(ack_packet)
		else
			$messege_handler.send_msg(@packet)
		end
	end

	def receive_ack
		puts "COMMAND_HANDLER: receive_ack"

		if @dest_node == $hostname
			if $timeout_map.has_key?(@ack_num)
				original_packet = $timeout_map[@ack_num]["PACKET"]
				puts "Found original packet: #{original_packet}"
				if original_packet.get_type == "PING"
					seq_id = original_packet.get_data
					target_node = @packet.get_origin_node
					rtt = $clock - $timeout_map[@ack_num]["TIMEOUT"]
					rtt = rtt.round(5)
					puts "\t#{seq_id} #{target_node} #{rtt}"
					$timeout_map.delete(@ack_num)
				elsif

					begin
						puts "printing traceroute"
						sent_time = original_packet.get_data.to_f
						hop_count = @ttl
						time_to_node = ($timeout_map[@ack_num]["TIMEOUT"] - sent_time).round(5)
						ts_str = "#{hop_count} #{@origin_node} #{time_to_node}"
						puts ts_str
						puts "Time sent: [#{sent_time}] vs dest_timestamp: [#{$timeout_map[@ack_num]["TIMEOUT"]}] at time: [#{$clock.to_f}]"
					rescue Exception => e
						puts "Trace Exception: #{e}"
					end
					
				end
				puts "Timeout map after deleting ack_num: #{$timeout_map}"
			end
		else
			$messege_handler.send_msg(@packet)
		end	
	end

	def self.dijkstra
		destinations = []

		$flood_map.each do |source_node, dest_hash|
			if !destinations.include?(source_node)
				destinations << source_node
			end

			dest_hash.each do |dest_node, cost|
				if !destinations.include?(dest_node)
					destinations << dest_node
				end
			end
		end

		dist = {}
		prev = {}
		vertex_list = []

		destinations.each do |dest_node|
			dist[dest_node] = Float::INFINITY
			prev[dest_node] = nil
			vertex_list << dest_node
		end

		dist[$hostname] = 0
		prev[$hostname] = $hostname

		while !vertex_list.empty? do
			u = nil
			idx = 0
			vertex_list.each_with_index do |node, i|

				if u.nil? or dist[node] < dist[u]
					u = node
					idx = i
				end
			end
			vertex_list.delete_at(idx)
			next if $flood_map[u].nil?
			$flood_map[u].each do |v, cost|
				alt = dist[u] + cost
				if alt < dist[v]
					dist[v] = alt
					prev[v] = u
				end
			end
		end
		
		destinations.each do |node|
		 	next if node == $hostname
		 	
		 	if $routing_table[node].nil? then $routing_table[node] = {} end

		 	if dist[node] == Float::INFINITY
		 		$routing_table.delete(node)
		 		next
		 		#$routing_table[node] ={}
		 	end



		 	

			$routing_table[node]["DIST"] = dist[node]
			
			if prev[node] == $hostname
				$routing_table[node]["NEXT_NODE"] = node
			else
				mnext = node#prev[node]
				i = 10
				while prev[prev[mnext]] != $hostname and i > 0

					mnext = prev[mnext]

					i -= 1
				end
				$routing_table[node]["NEXT_NODE"] = prev[mnext]
			end
			
		end
	end

	def receive_flood
		puts "COMMAND_HANDLER: receive_flood()"
		return if @origin_node == $hostname
				
		lst = @data.split(";")
		
		begin
			flood_map_changed = false
			
			if $flood_map[@origin_node].nil?	
				hash_copy = {}
			else
				hash_copy = $flood_map[@origin_node].dup
			end
			$flood_map[@origin_node] = {}
			

			lst.each do |flood_data|
				items = flood_data.split(" ")
			  	neighbor = items[0]
			  	neighbor_dist = items[1].to_i
			  	$flood_map[@origin_node][neighbor] = neighbor_dist
			end

			if hash_copy.keys.size != $flood_map[@origin_node].keys.size
				flood_map_changed = true
			else
				hash_copy.each do |dest, cost|
					if $flood_map[@origin_node][dest].nil? \
						or $flood_map[@origin_node][dest] != cost
						flood_map_changed = true
					end
				end
			end

			if flood_map_changed
				self.class.dijkstra
			end
		rescue Exception => e
			puts "COMMAND_HANDLER: Exception => #{e}" 
		end

		$neighbors.each do |n|
			next if n == @packet.get_origin_node
			
			new_packet = Packet.new(@packet.to_s)
			new_packet.set_dest_node(n)
			$messege_handler.send_msg(new_packet)
		end
	end

	def receive_edgeb
		puts "COMMAND_HANDLER: receive_edgeb"
		edgeb_add_mappings(@data)
		lst = @data.split($data_delim)
		source_node = lst[0]
		source_ip = lst[1]
		source_port = lst[2]

		$neighbors << source_node

		packet = Packet.new

		if $hostname == @dest_node
			packet.set_type("ACK")
			packet.set_dest_node(@origin_node)
			packet.set_data("NULL")

		else

		end
	end

	def edgeb_add_mappings(args)
		begin
		puts "COMMAND_HANDLER: adgeb_add_mappings(#{args})"
		
		arr = args.split(" ")
		
		dest_node = arr[0]
		
		if $flood_map[$hostname].nil?
			$flood_map[$hostname] = {}
		end
		$flood_map[$hostname][dest_node] = 1
		
		$routing_table[dest_node] = {}
		$routing_table[dest_node]["NEXT_NODE"] = dest_node
		$routing_table[dest_node]["DIST"] = 1
		
		rescue Exception => e
			puts "Exception => #{e}"
		end 
	end
end