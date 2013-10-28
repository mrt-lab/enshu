require "logger"

class MyLoadBalancer < Controller

 def start
  @fdb = {}
  @log = Logger.new('test.log', 7)
  @log.level = Logger::DEBUG
 end

 def switch_ready(dpid)
  #@fdb[dpid] = {}
 end

 def packet_in(dpid, message)
  if message.arp_request?
   handle_arp_request(dpid, message)
  elsif message.arp_reply?
   handle_arp_reply(dpid, message)
  elsif message.ipv4?
   handle_ipv4(dpid, message)
  end

  @fdb[message.macsa] = message.in_port
  port = @fdb[message.macda]
  if port
    add_flow(dpid, message, port)
    send_packet(dpid, message, port)
  else
    send_packet(dpid, message, OFPP_FLOOD)
  end
 end

 private

 def handle_arp_request(dpid, message)
  @log.debug("arp_request eth_type " + message.eth_type.to_s + " in_port : " + message.in_port.to_s + " sha : " + message.arp_sha.to_s + " spa : " + message.arp_spa.to_s + " tha : " + message.arp_tha.to_s + " tpa : " + message.arp_tpa.to_s)
=begin
  for addr in 128..254 do
   address = "192.168.0." + addr.to_s
   send_packet_out(
       dpid,
       :packet_in => message,
       :action => [SetIpDstAddr.new(address),
                   SendOutPort.new(OFPP_FLOOD)
                  ]
       )
  end
=end
 end

 def handle_arp_reply(dpid, message)
  @log.debug("arp_reply eth_type " + message.eth_type.to_s + " in_port : " + message.in_port.to_s + " sha : " + message.arp_sha.to_s + " spa : " + message.arp_spa.to_s + " tha : " + message.arp_tha.to_s + " tpa : " + message.arp_tpa.to_s)
 end

 def handle_ipv4(dpid, message)
  @log.debug("eth_type " + message.eth_type.to_s + " in_port : " + message.in_port.to_s + " nwsa : " + message.ipv4_saddr.to_s + " nwda : " + message.ipv4_daddr.to_s)
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
