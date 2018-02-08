class Packet

	
	def initialize(msg = "")
		
		if msg == ""
			@origin_node = "n0"
			
			@dest_node = "n0"
			@sequence_num = 0
			@ttl = 0
			@ack_number = 0
			@id = 0
			@frag = false
			@type = "NULL"
			@data = ""
		else
			arr = msg[1..-2].split(",")
			
			i = -1
			
			@origin_node = arr[i+=1]
			
			@dest_node = arr[i+=1]
			@sequence_num = arr[i+=1].to_i
			
			@ttl = arr[i+=1].to_i
			@ack_number = arr[i+=1].to_i
			@id = arr[i+=1]
			@frag = arr[i+=1] == "true"
			@type = arr[i+=1]
	
			@data = arr[i+=1]

		end
	end

	def get_ack_number
		return @ack_number
	end

	def set_ack_number(ack_num)
		@ack_number = ack_num
	end

	def get_ttl
		return @ttl
	end

	def set_ttl(ttl)
		@ttl = ttl
	end

	def get_origin_node
		return @origin_node
	end

	def get_dest_node
		return @dest_node
	end

	def get_seq
		return @sequence_num
	end

	def get_frag
		return @frag
	end

	def get_type
		return @type
	end

	def get_id
		return @id.to_i
	end

	def set_id(id)
		@id = id
	end

	def get_data
		return @data
	end

	def set_origin_node(node)
		@origin_node = node
	end

	def set_dest_node(node)
		@dest_node = node
	end

	def set_seq(sequence_num)
		@sequence_num = sequence_num
	end

	def set_frag(frag)
		@frag = frag
	end

	def set_type(type)
		@type = type
	end

	def set_data(data)
		@data = data
	end

	def to_s
		comma = ","
		s = "<"
		s += @origin_node + comma
		s += @dest_node + comma
		s += @sequence_num.to_s.rjust(3,"0") + comma
		s += @ttl.to_s.rjust(2,"0") + comma
		s += @ack_number.to_s.rjust(3,"0") + comma
		s += @id.to_s.rjust(4,"0") + comma
		s += @frag.to_s + comma
		s += @type.to_s + comma
		s += @data.to_s
		s += ">"
		return s
	end
end