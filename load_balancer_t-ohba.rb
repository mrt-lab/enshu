require "pio"
require "logger"

class MyLoadBalancer < Controller
 SERVER_BASE_ADDRESS = 250
 SERVER_COUNT = 4

 def start
  @fdb = {}
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
   handle_arp_reply(dpid, message)
  elsif message.ipv4?
   handle_ipv4(dpid, message)
  end
 end

 private

 def arp_request_to_server(dpid)
  for addr in SERVER_BASE_ADDRESS..SERVER_BASE_ADDRESS+SERVER_COUNT do
   address = '192.168.0.' + addr.to_s
   request = Pio::Arp::Request.new(
     :source_mac => '11:22:33:44:55:66',
     :sender_protocol_address => '192.168.0.1',
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

  send_packet(dpid, message, OFPP_FLOOD)
 end

 def handle_arp_reply(dpid, message)
  @log.debug("arp_reply eth_type " + message.eth_type.to_s + " in_port : " + message.in_port.to_s + " sha : " + message.arp_sha.to_s + " spa : " + message.arp_spa.to_s + " tha : " + message.arp_tha.to_s + " tpa : " + message.arp_tpa.to_s)

  send_packet(dpid, message, OFPP_FLOOD)
 end

 def handle_ipv4(dpid, message)
  @log.debug("eth_type " + message.eth_type.to_s + " in_port : " + message.in_port.to_s + " nwsa : " + message.ipv4_saddr.to_s + " nwda : " + message.ipv4_daddr.to_s)

  if port
    add_flow(dpid, message, port)
    send_packet(dpid, message, port)
  else
    send_packet(dpid, message, OFPP_FLOOD)
  end
 end

 def add_flow(dpid, message, port)
  send_flow_mod_add(
      dpid,
      :match => ExactMatch.from(message),
      :actions => Trema::SendOutPort.new(port)
     )
 end

 def send_packet(dpid, message, port)
  send_packet_out(
     dpid,
     :packet_in => message,
     :actions => Trema::SendOutPort.new(port)
    )
 end
end
