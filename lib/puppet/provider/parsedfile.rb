require 'puppet'
require 'puppet/filetype'
require 'puppet/util/fileparsing'

# This provider can be used as the parent class for a provider that
# parses and generates files.  Its content must be loaded via the
# 'prefetch' method, and the file will be written when 'flush' is called
# on the provider instance.  At this point, the file is written once
# for every provider instance.
#
# Once the provider prefetches the data, it's the model's job to copy
# that data over to the @is variables.
class Puppet::Provider::ParsedFile < Puppet::Provider
    extend Puppet::Util::FileParsing

    class << self
        attr_accessor :default_target, :target
    end

    attr_accessor :state_hash

    def self.clean(hash)
        newhash = hash.dup
        [:record_type, :on_disk].each do |p|
            if newhash.include?(p)
                newhash.delete(p)
            end
        end

        return newhash
    end

    def self.clear
        @target_objects.clear
        @records.clear
    end

    def self.filetype
        unless defined? @filetype
            @filetype = Puppet::FileType.filetype(:flat)
        end
        return @filetype
    end

    def self.filetype=(type)
        if type.is_a?(Class)
            @filetype = type
        elsif klass = Puppet::FileType.filetype(type)
            @filetype = klass
        else
            raise ArgumentError, "Invalid filetype %s" % type
        end
    end

    # Flush all of the targets for which there are modified records.  The only
    # reason we pass a record here is so that we can add it to the stack if
    # necessary -- it's passed from the instance calling 'flush'.
    def self.flush(record)
        # Make sure this record is on the list to be flushed.
        unless record[:on_disk]
            record[:on_disk] = true
            @records << record

            # If we've just added the record, then make sure our
            # target will get flushed.
            modified(record[:target] || default_target)
        end

        return unless defined?(@modified) and ! @modified.empty?

        flushed = []
        @modified.sort { |a,b| a.to_s <=> b.to_s }.uniq.each do |target|
            Puppet.debug "Flushing %s provider target %s" % [@model.name, target]
            flush_target(target)
            flushed << target
        end

        @modified.reject! { |t| flushed.include?(t) }
    end

    # Flush all of the records relating to a specific target.
    def self.flush_target(target)
        target_object(target).write(to_file(target_records(target).reject { |r|
            r[:ensure] == :absent
        }))
    end

    # Return the header placed at the top of each generated file, warning
    # users that modifying this file manually is probably a bad idea.
    def self.header
%{# HEADER: This file was autogenerated at #{Time.now}
# HEADER: by puppet.  While it can still be managed manually, it
# HEADER: is definitely not recommended.\n}
    end

    # Add another type var.
    def self.initvars
        @records = []
        @target_objects = {}

        @target = nil

        # Default to flat files
        @filetype = Puppet::FileType.filetype(:flat)
        super
    end

    # Return a list of all of the records we can find.
    def self.list
        prefetch()
        @records.find_all { |r| r[:record_type] == self.name }.collect { |r|
            clean(r)
        }
    end

    def self.list_by_name
        list.collect { |r| r[:name] }
    end

    # Create attribute methods for each of the model's non-metaparam attributes.
    def self.model=(model)
        [model.validstates, model.parameters].flatten.each do |attr|
            attr = symbolize(attr)
            define_method(attr) do
                # If it's not a valid field for this record type (which can happen
                # when different platforms support different fields), then just
                # return the should value, so the model shuts up.
                if @state_hash[attr] or self.class.valid_attr?(self.class.name, attr)
                    @state_hash[attr] || :absent
                else
                    @model.should(attr)
                end
            end

            define_method(attr.to_s + "=") do |val|
                # Mark that this target was modified.
                modeltarget = @model[:target] || self.class.default_target

                # If they're the same, then just mark that one as modified
                if @state_hash[:target] and @state_hash[:target] == modeltarget
                    self.class.modified(modeltarget)
                else
                    # Always mark the modeltarget as modified, and if there's
                    # and old state_hash target, mark it as modified and replace
                    # it.
                    self.class.modified(modeltarget)
                    if @state_hash[:target]
                        self.class.modified(@state_hash[:target])
                    end
                    @state_hash[:target] = modeltarget
                end
                @state_hash[attr] = val
            end
        end
        @model = model
    end

    # Mark a target as modified so we know to flush it.  This only gets
    # used within the attr= methods.
    def self.modified(target)
        @modified ||= []
        @modified << target unless @modified.include?(target)
    end

    # Retrieve all of the data from disk.  There are three ways to know
    # while files to retrieve:  We might have a list of file objects already
    # set up, there might be instances of our associated model and they
    # will have a path parameter set, and we will have a default path
    # set.  We need to turn those three locations into a list of files,
    # prefetch each one, and make sure they're associated with each appropriate
    # model instance.
    def self.prefetch
        # Reset the record list.
        @records = []
        targets().each do |target|
            prefetch_target(target)
        end
    end

    # Prefetch an individual target.
    def self.prefetch_target(target)
        @records += retrieve(target).each do |r|
            r[:on_disk] = true
            r[:target] = target
            r[:ensure] = :present
        end

        # Set current state on any existing resource instances.
        target_records(target).find_all { |i| i.is_a?(Hash) }.each do |record|
            # Find any model instances whose names match our instances.
            if instance = self.model[record[:name]]
                next unless instance.provider.is_a?(self)
                instance.provider.state_hash = record
            elsif self.respond_to?(:match)
                if instance = self.match(record)
                    record[:name] = instance[:name]
                    instance.provider.state_hash = record
                end
            end
        end
    end

    # Is there an existing record with this name?
    def self.record?(name)
        @records.find { |r| r[:name] == name }
    end

    # Retrieve the text for the file. Returns nil in the unlikely
    # event that it doesn't exist.
    def self.retrieve(path)
        # XXX We need to be doing something special here in case of failure.
        text = target_object(path).read
        if text.nil? or text == ""
            # there is no file
            return []
        else
            # Set the target, for logging.
            old = @target
            begin
                @target = path
                self.parse(text)
            ensure
                @target = old
            end

        end
    end

    # Initialize the object if necessary.
    def self.target_object(target)
        @target_objects[target] ||= @filetype.new(target)

        @target_objects[target]
    end

    # Find all of the records for a given target
    def self.target_records(target)
        @records.find_all { |r| r[:target] == target }
    end

    # Find a list of all of the targets that we should be reading.  This is
    # used to figure out what targets we need to prefetch.
    def self.targets
        targets = []
        # First get the default target
        unless self.default_target
            raise Puppet::DevError, "Parsed Providers must define a default target"
        end
        targets << self.default_target

        # Then get each of the file objects
        targets += @target_objects.keys

        # Lastly, check the file from any model instances
        self.model.each do |model|
            targets << model[:target]
        end

        targets.uniq.reject { |t| t.nil? }
    end

    def create
        @model.class.validstates.each do |state|
            if value = @model.should(state)
                @state_hash[state] = value
            end
        end
        self.class.modified(@state_hash[:target] || self.class.default_target)
        return (@model.class.name.to_s + "_created").intern
    end

    def destroy
        # We use the method here so it marks the target as modified.
        self.ensure = :absent
        return (@model.class.name.to_s + "_deleted").intern
    end

    def exists?
        if @state_hash[:ensure] == :absent or @state_hash[:ensure].nil?
            return false
        else
            return true
        end
    end

    # Write our data to disk.
    def flush
        # Make sure we've got a target and name set.

        # If the target isn't set, then this is our first modification, so
        # mark it for flushing.
        unless @state_hash[:target]
            @state_hash[:target] = @model[:target] || self.class.default_target
            self.class.modified(@state_hash[:target])
        end
        @state_hash[:name] ||= @model.name

        self.class.flush(@state_hash)
    end

    def initialize(model)
        super

        # See if there's already a matching state_hash in the records list;
        # else, use a default value.
        # We provide a default for 'ensure' here, because the provider will
        # override it if the thing exists, but it won't touch it if it doesn't
        # exist.
        @state_hash = self.class.record?(model[:name]) ||
            {:record_type => self.class.name, :ensure => :absent}
    end
end

# $Id$