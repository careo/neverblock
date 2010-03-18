require 'timeout'
require File.expand_path(File.dirname(__FILE__)+'/../../../neverblock')

module Timeout

  alias_method :rb_timeout, :timeout

  def timeout(time, klass=Timeout::Error, &block)
    return rb_timeout(time, klass,&block) unless NB.neverblocking?

    if time <= 0
      block.call
      return
    end

    fiber = NB::Fiber.current
    timeouts = (fiber[:timeouts] ||= [])

    timer = EM.add_timer(time) {
      idx = timeouts.index(timer)
      timers_to_cancel = timeouts.slice!(idx..timeouts.size-1)
      timers_to_cancel.each {|t| EM.cancel_timer(t) }
      handler = fiber[:io]
      handler.detach if handler
      fiber[:io] = nil
      fiber.resume(Timeout::Error.new)
    }    

    timeouts << timer

    begin
      block.call
    rescue Exception => e
      raise e
    ensure
      timeouts.delete(timer)
      EM.cancel_timer(timer)
    end

  end
  
  module_function :timeout  
  module_function :rb_timeout  

end





