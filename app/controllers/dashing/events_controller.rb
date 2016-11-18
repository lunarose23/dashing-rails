module Dashing
  class EventsController < ApplicationController
    include ActionController::Live

    def index
      response.headers['Content-Type']      = 'text/event-stream'
      response.headers['X-Accel-Buffering'] = 'no'
      response.headers['Access-Control-Allow-Origin'] = '*' # For Yaffle eventsource polyfill
      response.headers['Cache-Control'] = 'no-cache' # For Yaffle eventsource polyfill
      response.stream.write latest_events

      @redis = Dashing.redis
      @redis.psubscribe("#{Dashing.config.redis_namespace}.*") do |on|
        on.pmessage do |pattern, event, data|
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
