#  Created by Luke Kanies on 2006-11-07.
#  Copyright (c) 2006. All rights reserved.

class Puppet::Feature
    # Create a new feature test.  You have to pass the feature name,
    # and it must be unique.  You can either provide a block that
    # will get executed immediately to determine if the feature
    # is present, or you can pass an option to determine it.
    # Currently, the only supported option is 'libs' (must be
    # passed as a symbol), which will make sure that each lib loads
    # successfully.
    def add(name, options = {})
        method = name.to_s + "?"
        if self.class.respond_to?(method)
            raise ArgumentError, "Feature %s is already defined" % name
        end
        
        result = true
        if block_given?
            begin
                result = yield
            rescue => detail
                warn "Failed to load feature test for %s: %s" % [name, detail]
                result = false
            end
        end
        
        if ary = options[:libs]
            ary = [ary] unless ary.is_a?(Array)
            
            ary.each do |lib|
                unless lib.is_a?(String)
                    raise ArgumentError, "Libraries must be passed as strings not %s" % lib.class
                end
            
                begin
                    require lib
                rescue Exception
                    Puppet.debug "Failed to load library '%s' for feature '%s'" % [lib, name]
                    result = false
                end
            end
        end
        
        meta_def(method) do
            result
        end
    end
    
    # Create a new feature collection.
    def initialize(path)
        @path = path
    end
    
    def load
        loader = Puppet::Autoload.new(self, @path)
        loader.loadall
    end
end

# $Id$