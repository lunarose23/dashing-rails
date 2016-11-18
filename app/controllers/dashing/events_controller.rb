module Dashing
  class EventsController < ApplicationController
    include ActionController::Live

    def index
      response.headers['Content-Type']      = 'text/event-stream'
      response.headers['X-Accel-Buffering'] = 'no'
      response.headers['Access-Control-Allow-Origin'] = '*' # For Yaffle eventsource polyfill
      response.headers['Cache-Control'] = 'no-cache' # For Yaffle eventsource polyfill
      response.stream.write latest_events

      stream :keep_open do |out|
        settings.connections << out
      
        # For Yaffle eventsource polyfill
        #Add 2k padding for IE
        str = ":".ljust(2049) << "\n"
        #add retry key
        str << "retry: 2000\n"
        out << str
        
        out << latest_events
        out.callback { settings.connections.delete(out) }
      end

      @redis = Dashing.redis
      @redis.psubscribe("#{Dashing.config.redis_namespace}.*") do |on|
        on.pmessage do |pattern, event, data|
          response.stream.write("data: #{data}\n\n")
        end
      end
    rescue IOError
      logger.info "[Dashing][#{Time.now.utc.to_s}] Stream closed"
    ensure
      @redis.quit
      response.stream.close
    end

    def latest_events
      events = Dashing.redis.hvals("#{Dashing.config.redis_namespace}.latest")
      events.map { |v| "data: #{v}\n\n" }.join
    end
  end
end
