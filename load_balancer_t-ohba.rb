require "pio"
require "logger"

class MyLoadBalancer < Controller
 SERVER_BASE_ADDRESS = 128
 SERVER_COUNT = 126
 HARD_TIMEOUT = 1

 def start
  @fdb = {}
  @server_list = {}
  @server_ip = []
  @log = Logger.new('test.log', 7)
  @log.level = Logger::DEBUG
 end

 def switch_ready(dpid)
  arp_request_to_server(dpid)
 end

 def packet_in(dpid, message)
  @fdb[message.macsa] = message.in_port
  port = @fdb[message.macda]
  
  if message.arp_request?
   handle_arp_request(dpid, message)
  elsif message.arp_reply?
   handle_arp_reply(dpid, message, port)
  elsif message.ipv4?
   handle_ipv4(dpid, message, port)
  end
 end

 private

 def arp_request_to_server(dpid)
  for addr in SERVER_BASE_ADDRESS..SERVER_BASE_ADDRESS+SERVER_COUNT do
   address = '192.168.0.' + addr.to_s
   request = Pio::Arp::Request.new(
     :source_mac => '11:22:33:44:55:66',
     :sender_protocol_address => '192.168.0.11',
     :target_protocol_address => address
   )
   send_packet_out(
       dpid,
       :data => request.to_binary,
       :actions => SendOutPort.new(OFPP_FLOOD)
       )
  end
 end

 def handle_arp_request(dpid, message)
  @log.debug("arp_request eth_type " + message.eth_type.to_s + " in_port : " + message.in_port.to_s + " sha : " + message.arp_sha.to_s + " spa : " + message.arp_spa.to_s + " tha : " + message.arp_tha.to_s + " tpa : " + message.arp_tpa.to_s)

  action = [SendOutPort.new(OFPP_FLOOD)]
  add_flow(dpid, 0, message, action)
  send_packet(dpid, message, action)
 end

 def handle_arp_reply(dpid, message, port)
  @log.debug("arp_reply eth_type " + message.eth_type.to_s + " in_port : " + message.in_port.to_s + " sha : " + message.arp_sha.to_s + " spa : " + message.arp_spa.to_s + " tha : " + message.arp_tha.to_s + " tpa : " + message.arp_tpa.to_s)

  register_server(message)
  action = [SendOutPort.new(OFPP_FLOOD)]
  add_flow(dpid, 0, message, action)
  send_packet(dpid, message, action)
 end

 def register_server(message)
  address = message.arp_spa.to_s.split(".")[3].to_i
  if ( address >= SERVER_BASE_ADDRESS ) && ( @server_ip.index(message.arp_spa.to_s).nil? )
    @server_list[message.arp_spa.to_s] = message.arp_sha
    @server_ip << message.arp_spa.to_s
    @log.debug("register : src_ip " + message.arp_spa.to_s + " src_mac " + message.arp_sha.to_s + " length = " + @server_ip.length.to_s)
  end
 end

 def handle_ipv4(dpid, message, port)
  @log.debug("eth_type " + message.eth_type.to_s + " in_port : " + message.in_port.to_s + " nwsa : " + message.ipv4_saddr.to_s + " nwda : " + message.ipv4_daddr.to_s)

  address = message.ipv4_daddr.to_s.split(".")[3].to_i
  if address >= SERVER_BASE_ADDRESS
    to_server = true
  else
    to_server = false
  end

  if to_server
    address = @server_ip[rand(@server_ip.length)]
    action = [
      SetIpDstAddr.new(address),
      SetEthDstAddr.new(@server_list[address]),
      SendOutPort.new(@fdb[@server_list[address]])
    ]
    add_flow(dpid, 1, message, action)
    send_packet(dpid, message, action)
  else
    if port
      add_flow(dpid, 1, message, SendOutPort.new(port))
      send_packet(dpid, message, SendOutPort.new(port))
    else
      send_packet(dpid, message, SendOutPort.new(OFPP_FLOOD))
    end
  end 
 end

 def add_flow(dpid, time, message, action)
  send_flow_mod_add(
      dpid,
      :hard_timeout => time,
      :match => Match.from(message),
      :actions => action
     )
 end

 def send_packet(dpid, message, action)
  send_packet_out(
     dpid,
     :packet_in => message,
     :actions => action
    )
 end
end
