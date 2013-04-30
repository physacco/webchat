# -*- encoding: UTF-8 -*-

require 'base64'
require 'curb'
require 'nokogiri'

# Session Dump example:
#   <body rid="11687" xmlns="http://jabber.org/protocol/httpbind" xmpp:version="1.0" xmlns:xmpp="urn:xmpp:xbosh" wait="5" to="localhost" hold="3" window="5"/>
#   <body rid="11688" xmlns="http://jabber.org/protocol/httpbind" xmpp:version="1.0" xmlns:xmpp="urn:xmpp:xbosh" sid="5453189557bf49282c87902975ed8434865f336a"><auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="PLAIN">emhhbmdxaUBsb2NhbGhvc3QAemhhbmdxaQAxMjM0NTY=</auth></body>
#   <body rid="11689" xmlns="http://jabber.org/protocol/httpbind" xmpp:version="1.0" xmlns:xmpp="urn:xmpp:xbosh" sid="5453189557bf49282c87902975ed8434865f336a" xmpp:restart="true"/>
#   <body rid="11690" xmlns="http://jabber.org/protocol/httpbind" xmpp:version="1.0" xmlns:xmpp="urn:xmpp:xbosh" sid="5453189557bf49282c87902975ed8434865f336a"><iq id="bind_25270" type="set" xmlns="jabber:client"><bind xmlns="urn:ietf:params:xml:ns:xmpp-bind"><resource>webchat</resource></bind></iq></body>
#   <body rid="11691" xmlns="http://jabber.org/protocol/httpbind" xmpp:version="1.0" xmlns:xmpp="urn:xmpp:xbosh" sid="5453189557bf49282c87902975ed8434865f336a"><iq xmlns="jabber:client" type="set" id="sess_19029"><session xmlns="urn:ietf:params:xml:ns:xmpp-session"/></iq></body>

class RubyBOSH
  BOSH_XMLNS    = 'http://jabber.org/protocol/httpbind'
  TLS_XMLNS     = 'urn:ietf:params:xml:ns:xmpp-tls'
  SASL_XMLNS    = 'urn:ietf:params:xml:ns:xmpp-sasl'
  BIND_XMLNS    = 'urn:ietf:params:xml:ns:xmpp-bind'
  SESSION_XMLNS = 'urn:ietf:params:xml:ns:xmpp-session'
  CLIENT_XMLNS  = 'jabber:client'

  class Error < StandardError; end
  class Timeout < RubyBOSH::Error; end
  class AuthFailed < RubyBOSH::Error; end
  class ConnFailed < RubyBOSH::Error; end

  @@logging = false
  def self.logging=(value)
    @@logging = value
  end

  attr_accessor :jid, :rid, :sid, :success , :custom_resource

  def initialize(jid, pw, service_url, opts={}) 
    @service_url = service_url
    # Extract the resource if present
    split_jid = jid.split("/")
    @jid = split_jid.first
    @custom_resource = split_jid.last if split_jid.length > 1
    @pw = pw
    @host = @jid.split("@").last
    @success = false
    @timeout = opts[:timeout] || 3 #seconds 
    @headers = {"Content-Type" => "text/xml; charset=utf-8",
                "Accept" => "text/xml"}
    @wait    = opts[:wait]   || 50
    @hold    = opts[:hold]   || 1
    @window  = opts[:window] || 5
  end

  def success?
    @success == true
  end

  def self.initialize_session(*args)
    new(*args).connect
  end

  def connect
    initialize_bosh_session  # this should set @sid
    if send_auth_request 
      send_restart_request
      request_resource_binding
      @success = send_session_request
    end

    raise RubyBOSH::AuthFailed, "could not authenticate #{@jid}" unless success?
    @rid += 1 #updates the rid for the next call from the browser
    
    [@jid, @sid, @rid]
  end

  private
  def initialize_bosh_session
    @rid ? @rid+=1 : @rid=rand(100000)
    request = %Q|<body rid="#{@rid}" xmlns="http://jabber.org/protocol/httpbind" xmpp:version="1.0" xmlns:xmpp="urn:xmpp:xbosh" wait="#{@wait}" to="#{@host}" hold="#{@hold}" window="#{@window}"/>|
    response = deliver(request)
    parse(response)
  end

  def send_auth_request 
    @rid ? @rid+=1 : @rid=rand(100000)
    auth_string = "#{@jid}\x00#{@jid.split("@").first.strip}\x00#{@pw}" 
    auth = Base64.encode64(auth_string).gsub(/\s/,'')
    request = %Q|<body rid="#{@rid}" xmlns="http://jabber.org/protocol/httpbind" xmpp:version="1.0" xmlns:xmpp="urn:xmpp:xbosh" sid="#{@sid}"><auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" mechanism="PLAIN">#{auth}=</auth></body>|

    response = deliver(request)
    response.include?("success")
  end

  def send_restart_request
    @rid ? @rid+=1 : @rid=rand(100000)
    request = %Q|<body rid="#{@rid}" xmlns="http://jabber.org/protocol/httpbind" xmpp:version="1.0" xmlns:xmpp="urn:xmpp:xbosh" sid="#{@sid}" xmpp:restart="true"/>|
    deliver(request).include?("stream:features")
  end

  def request_resource_binding
    @rid ? @rid+=1 : @rid=rand(100000)
    request = %Q|<body rid="#{@rid}" xmlns="http://jabber.org/protocol/httpbind" xmpp:version="1.0" xmlns:xmpp="urn:xmpp:xbosh" sid="#{@sid}"><iq id="bind_#{rand(100000)}" type="set" xmlns="jabber:client"><bind xmlns="urn:ietf:params:xml:ns:xmpp-bind"><resource>#{resource_name}</resource></bind></iq></body>|
    
    response = deliver(request)
    response.include?("<jid>") 
  end

  def send_session_request
    @rid ? @rid+=1 : @rid=rand(100000)
    request = %Q|<body rid="#{@rid}" xmlns="http://jabber.org/protocol/httpbind" xmpp:version="1.0" xmlns:xmpp="urn:xmpp:xbosh" sid="#{@sid}"><iq xmlns="jabber:client" type="set" id="sess_#{rand(100000)}"><session xmlns="urn:ietf:params:xml:ns:xmpp-session"/></iq></body>|

    response = deliver(request)
    response.include?("body") 
  end

  def parse(_response)
    doc = Nokogiri::XML(_response)
    @sid = (doc/'body').first.attr('sid')
    _response
  end

  def deliver(xml)
    log_send(xml)
    body = http_post(@service_url, xml, @headers)
    log_recv(body)  # this should return body again
  rescue Errno::ECONNREFUSED => e
    raise RubyBOSH::ConnFailed, "could not connect to #{@host}\n#{e.message}"
  rescue Exception => e
    raise RubyBOSH::Error, e.message
  end

  def http_post(uri, body, headers={})
    curl = Curl::Easy.new(uri)
    curl.connect_timeout = 5
    curl.timeout = 5
    curl.follow_location = false
    headers.each{ |k, v| curl.headers[k] = v }     # merge request headers
    curl.http_post(body)
    
    #_status_line, _header_lines = curl.header_str.split("\r\n")
    #_status = _status_line.split(" ")[1].to_i       # 200,404,500...
    curl.body_str
  end

  def log_send(msg)
    puts("Ruby-BOSH - SEND [#{now}]:\n\t#{msg}") if @@logging; msg
  end

  def log_recv(msg)
    puts("Ruby-BOSH - RECV [#{now}]:\n\t#{msg}") if @@logging; msg
  end

  private
  def now 
    Time.now.strftime("%a %b %d %H:%M:%S %Y")
  end

  def get_rid
    @rid ? @rid+=1 : @rid=rand(100000)
  end

  def resource_name
    if @custom_resource.nil?
      "bosh_#{rand(10000)}"
    else
      @custom_resource
    end
  end
end

if __FILE__ == $0
  if ARGV.size < 2
    STDERR.puts 'Usage: ruby_bosh.rb username password'
    exit(1)
  end

  t1 = Time.now
  session = RubyBOSH.initialize_session(ARGV[0], ARGV[1], 
      "http://localhost:5280/http-bind")
  t2 = Time.now
  dt = t2 - t1
  puts "Session: #{session.inspect}"
  puts "Time elapsed: #{dt}"
end
