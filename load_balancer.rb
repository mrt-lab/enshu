require 'logger'##


class SendPacket < Controller
  def start
    @switch = Hash.new{ |hash,key| hash[key] = {} }
    @log = Logger.new('foo.log',7)##
    @log.level = Logger::DEBUG##

  end



  def switch_ready dpid
    @switch[dpid] = {}
    puts dpid.to_hex
    @log.debug("message!!\n")##
  end

  def packet_in dpid, message
    @switch[dpid][message.macsa] = message.in_port
    port = @switch[dpid][message.macda]
    if port
      send_flow_mod_add(
                        dpid,
                        :match => Match.new(:in_port => port,
                                            :dl_dst => message.macda), 
                        :actions => Trema::SendOutPort.new(port))
    else
      port = OFPP_FLOOD
    end
    send_packet_out(
                    dpid,
                    :packet_in => message,
                    :actions => Trema::SendOutPort.new(port))
  end
end
