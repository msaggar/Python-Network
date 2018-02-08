require 'socket'
require_relative 'packet'
require_relative 'command_handler'

class Listener
	
	def initialize(port)
		@port = port
		@timeout = 2
		@in_queue = []
		@in_string = ""
		@frag_queue = {}
	end

	def add_client
		begin
			client = @server.accept_nonblock or
				raise "LISTENER: incoming connection, but no client"
		rescue Exception => e
			puts "LISTENER: @server.accept_nonblock => #{e}"
		end

		$connections << client
	end

	def start_command_handler
		loop do
			puts "loopp"
			if !@in_queue.empty?
				packet = @out_queue.shift
				puts "sending packet #{packet}"
			end
		end
	end

	def start
		puts "LISTENER: start()"
		@server = TCPServer.open(@port)

		#start_command_handler
		loop do
			begin
			$timeout_map.each do |seq, hash|
				timeout = hash["TIMEOUT"]
				
				if $clock >= timeout + $ping_timeout

					if hash["TYPE"] == "SENDMSG"
						puts "SENDMSG ERROR: HOST UNREACHABLE"
					elsif hash["TYPE"] == "PING"
						puts "PING ERROR: HOST UNREACHABLE"
						puts "seq #{seq}"
					elsif	hash["TYPE"] == "TRACE"
						# puts "SENDMSG ERROR: HOST UNREACHABLE"
						puts "TIMEOUT on #{$clock.to_i - timeout}"
					else
						puts "invalid type"
					end
					$timeout_map.delete(seq)
					
				end	
			end
			rescue Exception => e
				puts "Exception => #{e}"
			end


			begin
				readable, writable = IO.select([@server]+$connections, [])#$connections)
			rescue Exception => e
				puts "LISTENER IO.select Exception => #{e}"
			end

			# loop runs over server and connections
			# looking for server
			readable.each do |socket|
				next if socket != @server
				add_client
			end

			# looking for clients
			readable.each do |socket|
				next if socket == @server
				
				if !socket.eof?
					begin
						while msg_in = socket.read_nonblock(20)
							begin
								
								msg_in.chomp!
								regexp = /\<([a-zA-z0-9]*,){7}[A-Z]+,[^<]*\>/

								@in_string += msg_in
								msg_lst = @in_string.partition(regexp)
								
								if msg_lst[1] != ""
									@in_queue << msg_lst[1]
									@in_string = msg_lst[2]
								end

								while !@in_queue.empty?

									msg = @in_queue.shift
						
									packet = Packet.new(msg)
									packet.set_ttl(packet.get_ttl + 1)
									puts "LISTENER: received [#{packet}] @#{$clock % 60}"

									packet_seq = packet.get_seq
									origin = packet.get_origin_node

									is_frag = packet.get_frag

									data = packet.get_data
									id = packet.get_id

									if is_frag
									
										if @frag_queue[packet_seq].nil? then @frag_queue[packet_seq] = {} end

										@frag_queue[packet_seq][id] = data.dup

									end

									if id != 0 and !is_frag
										@frag_queue[packet_seq][id] = data.dup
										
										curr_id = 0
										new_data = ""
										(0..@frag_queue[packet_seq].keys.size).each do |mid|
											

											new_data += @frag_queue[packet_seq][curr_id].to_s

											curr_id += 1
										end
										
										packet.set_data(new_data)
										@frag_queue.delete(packet_seq)

									end

									if origin != $hostname and packet_seq > $node_socket_info[origin]["SEQIN"] and !is_frag
										puts "LISTENER: parsing #{packet}"


										CommandHandler.new(packet)
										$node_socket_info[origin]["SEQIN"] = packet_seq
									elsif !is_frag
										puts "Rejecting packet with seq: #{packet.get_seq} < #{$node_socket_info[origin]["SEQIN"]}"
									end
								end
							rescue Exception => e
								#this will throw after input if done being read, but its ok
								puts "\tLISTENER: Exception => #{e}"
							end

						end
					rescue Exception => e
						#this will throw after input if done being read, but its ok
					end
				end
			end
		end
	end
end