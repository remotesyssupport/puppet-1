# Ruby gems support.
Puppet::Type.type(:package).provide :gem do
    desc "Ruby Gem support.  By default uses remote gems, but you can specify
        the path to a local gem via ``source``."
    GEM = binary("gem")

    confine :exists => GEM

    def self.gemlist(hash)
        command = "#{GEM} list "

        if hash[:local]
            command += "--local "
        else
            command += "--remote "
        end

        if name = hash[:justme]
            command += name
        end
        begin
            list = execute(command).split("\n\n").collect do |set|
                if gemhash = gemsplit(set)
                    gemhash[:provider] = :gem
                    gemhash[:ensure] = gemhash[:version][0]
                    gemhash
                else
                    nil
                end
            end.reject { |p| p.nil? }
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not list gems: %s" % detail
        end

        if hash[:justme]
            return list.shift
        else
            return list
        end
    end

    def self.gemsplit(desc)
        case desc
        when /^\*\*\*/: return nil
        when /^(\S+)\s+\((.+)\)\n/
            name = $1
            version = $2.split(/,\s*/)
            return {
                :name => name,
                :version => version
            }
        else
            Puppet.warning "Could not match %s" % desc
            nil
        end
    end

    def self.list(justme = false)
        gemlist(:local => true).each do |hash|
            Puppet::Type.type(:package).installedpkg(hash)
        end
    end

    def install(useversion = true)
        command = "#{GEM} install "
        if @model[:version] and useversion
            command += "-v %s " % @model[:version]
        end
        if source = @model[:source]
            command += source
        else
            command += @model[:name]
        end
        begin
            execute(command)
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not install %s: %s" %
                [@model[:name], detail]
        end
    end

    def latest
        # This always gets the latest version available.
        hash = self.class.gemlist(:justme => @model[:name])

        return hash[:version][0]
    end

    def query
        self.class.gemlist(:justme => @model[:name], :local => true)
    end

    def uninstall
        begin
            # Remove everything, including the binaries.
            execute("#{GEM} uninstall -x -a #{@model[:name]}")
        rescue Puppet::ExecutionFailure => detail
            raise Puppet::Error, "Could not uninstall %s: %s" %
                [@model[:name], detail]
        end
    end

    def update
        self.install(false)
    end
end

# $Id$