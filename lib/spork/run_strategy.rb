class Spork::RunStrategy
  attr_reader :test_framework
  @@run_strategies = []

  def initialize(test_framework)
    @test_framework = test_framework
    @state = nil
  end

  def preload
    return unless @state == nil
    @state = :preloading
    result = do_preload
    @state = :ready
    result
  end

  def run(argv, stderr, stdout)
    raise RuntimeError, "RunStrategy#preload has not been invoked" if @state == nil
    sleep 0.1 while @state == :preloading
    do_run(argv, stderr, stdout)
  end

  def preload_in_background
    Thread.new do
      begin
        preload
      rescue Object => e
        puts "#{e} (#{e.class})"
        puts e.backtrace
        exit(1)
      end
    end
  end

  def running?
    raise NotImplementedError
  end

  def self.factory(test_framework)
    Spork::RunStrategy::Forking.new(test_framework)
  end

  def abort
    do_abort if running?
  end

  def abort_or_quit_server
    if running?
      abort
      $stderr.puts "Running tests stopped.  Press CTRL-C again to quit."
      $stderr.flush
    else
      Spork::EventDispatcher[:interrupt].trigger(:quit)
    end
  end

  def setup_observers
    Spork::EventDispatcher[:work].observe(:preload) { |payload| preload }
    Spork::EventDispatcher[:work].observe(:run) { |args| run(*args) }
    Spork::EventDispatcher[:interrupt].observe(:abort) { |payload| abort }
    Spork::EventDispatcher[:interrupt].observe(:sigint) { |payload| abort_or_quit_server }
    trap("SIGINT") do
      Spork::EventDispatcher[:interrupt].trigger(:sigint)
    end
  end

  protected
    def do_abort
      raise NotImplementedError
    end

    def self.inherited(subclass)
      @@run_strategies << subclass
    end

    def do_preload
      raise NotImplementedError
    end

    def do_run(argv, input, output)
      raise NotImplementedError
    end

    def do_cleanup
      raise NotImplementedError
    end
end

Dir[File.dirname(__FILE__) + "/run_strategy/*.rb"].each { |file| require file }
