require 'puppet/application'
require 'puppet/util'

class Puppet::Application::Queue < Puppet::Application
  should_parse_config

  attr_accessor :daemon

  def preinit
    require 'puppet/daemon'
    @daemon = Puppet::Daemon.new
    @daemon.argv = ARGV.dup
    Puppet::Util::Log.newdestination(:console)

    # Do an initial trap, so that cancels don't get a stack trace.

    # This exits with exit code 1
    trap(:INT) do
      $stderr.puts "Caught SIGINT; shutting down"
      exit(1)
    end

    # This is a normal shutdown, so code 0
    trap(:TERM) do
      $stderr.puts "Caught SIGTERM; shutting down"
      exit(0)
    end

    {
      :verbose => false,
      :debug => false
    }.each do |opt,val|
      options[opt] = val
    end
  end

  option("--debug","-d")
  option("--verbose","-v")

  def main
    require 'lib/puppet/indirector/catalog/queue' # provides Puppet::Indirector::Queue.subscribe
    Puppet.notice "Starting puppetqd #{Puppet.version}"
    Puppet::Resource::Catalog::Queue.subscribe do |catalog|
      # Once you have a Puppet::Resource::Catalog instance, calling save on it should suffice
      # to put it through to the database via its active_record indirector (which is determined
      # by the terminus_class = :active_record setting above)
      Puppet::Util.benchmark(:notice, "Processing queued catalog for #{catalog.name}") do
        begin
          catalog.save
        rescue => detail
          puts detail.backtrace if Puppet[:trace]
          Puppet.err "Could not save queued catalog for #{catalog.name}: #{detail}"
        end
      end
    end

    Thread.list.each { |thread| thread.join }
  end

  # Handle the logging settings.
  def setup_logs
    if options[:debug] or options[:verbose]
      Puppet::Util::Log.newdestination(:console)
      if options[:debug]
        Puppet::Util::Log.level = :debug
      else
        Puppet::Util::Log.level = :info
      end
    end
  end

  def setup
    unless Puppet.features.stomp?
      raise ArgumentError, "Could not load the 'stomp' library, which must be present for queueing to work.  You must install the required library."
    end

    setup_logs

    exit(Puppet.settings.print_configs ? 0 : 1) if Puppet.settings.print_configs?

    require 'puppet/resource/catalog'
    Puppet::Resource::Catalog.terminus_class = :active_record

    daemon.daemonize if Puppet[:daemonize]

    # We want to make sure that we don't have a cache
    # class set up, because if storeconfigs is enabled,
    # we'll get a loop of continually caching the catalog
    # for storage again.
    Puppet::Resource::Catalog.cache_class = nil
  end
end
