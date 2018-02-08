require 'socket'
require 'timeout'

class MessegeHandler

	@port = nil
	@out_queue = nil

	def initialize(port)
		puts "MESSAGE_HANDLER: initialize(#{port})"
		@port = port
		@out_queue = []
	end

	def start
		puts "MESSAGE_HANDLER: start()"

		loop do

			
			$ping_queue.each do |time, packet|
				if time <= $clock
					send_msg(packet)
					$ping_queue.delete(time)
				
				end
			end

			if !@out_queue.empty?

				begin
				
				packet = @out_queue.shift
				
				if packet.get_type == "SENDMSG" || packet.get_type == "PING" || packet.get_type == "TRACE"
					seq = packet.get_seq
					$timeout_map[seq] = {}
					$timeout_map[seq]["TIMEOUT"] = $clock
					$timeout_map[seq]["PACKET"] = packet
					$timeout_map[seq]["TYPE"] = packet.get_type
					puts "\tTimeout map: #{$timeout_map}"
				end
		
				dest_node = packet.get_dest_node
				if $routing_table[dest_node].nil? then 
					puts "skipping dest_node #{dest_node}"
					next 
				end

				next_node = $routing_table[dest_node]["NEXT_NODE"]
				next_port = $node_socket_info[next_node]["PORT"]
				next_ip = $node_socket_info[next_node]["IP"]
				next_socket = $node_socket_info[next_node]["SOCKET"]
				rescue Exception => e
					puts "Exception => #{e}"
				end

				if next_socket == nil
					tries = 0
					max_tries = 5
					while !next_socket && tries < max_tries 
						begin
							next_socket = TCPSocket.new(next_ip, next_port)
						rescue Exception => e
						end

						if !next_socket
							puts "MESSAGE_HANDLER sleeping"
							sleep 0.1
						end
						tries += 1
					end
					
					$node_socket_info[next_node]["SOCKET"] = next_socket
				end

				$connections << next_socket

				begin
					next_socket.puts(packet.to_s)
					puts "MESSAGE_HANDLER: sent [#{packet}] SEQ[#{packet.get_seq}] @#{$clock}"
				rescue Exception => e
					puts "HANDLER: next_socket.puts(packet.to_s) => #{e}"
				end


			end
			

			sleep 0.1
		end
	end

	def send_msg(packet)
		puts "send_msg(#{packet}) @#{$clock % 60}"# if packet.get_type == "SENDMSG"
	
		if packet.get_origin_node == $hostname
			packet.set_seq($sequence_number)
			$sequence_number += 1
		end


		packet.set_frag(true)
		if packet.get_data.nil?
			data = ""
		else
			data = packet.get_data.dup
		end
		begin

		id = 0


		segment = data[0,$max_payload]
		remaining = data[$max_payload..-1]

		while !remaining.nil? and !remaining.empty?#and i > 0
			
			packet.set_data(segment.dup)
			packet.set_id(id)
			id += 1
			segment = remaining[0,$max_payload]
			if remaining.size < $max_payload
				remaining = nil
			else
				remaining = remaining[$max_payload..-1]
			end

			@out_queue.push packet.dup
		end
		packet.set_data(segment.dup)
		packet.set_frag(false)
		packet.set_id(id)
		@out_queue.push packet

		rescue Exception => e
			puts "Exception => #{e}"
		end
	end
end