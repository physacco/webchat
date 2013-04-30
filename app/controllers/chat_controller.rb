require 'ruby_bosh'

class ChatController < ApplicationController
  def index
    begin
      @host = "localhost"
      @bosh = "http://localhost:5280/http-bind"
      @muchost = "conference.#{@host}"

      username = "foo"
      password = "123456"
      @jid = "#{username}@#{@host}/webchat#{rand(1000000)}"

      _jid, @sid, @rid = RubyBOSH.initialize_session(@jid, password, @bosh)

      @lang = I18n.locale == :zh ? 'cn' : I18n.locale.to_s
    rescue Exception => e
      errmsg = "#{e.class}: #{e.message}\n\n"
      errmsg += e.backtrace.join("\t\n")
      logger.error errmsg
      @error = true
    end
  end
end
