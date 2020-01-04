# This is an autogenerated function, ported from the original legacy version.
# It /should work/ as is, but will not have all the benefits of the modern
# function API. You should see the function docs to learn how to add function
# signatures for type safety and to document this function using puppet-strings.
#
# https://puppet.com/docs/puppet/latest/custom_functions_ruby.html
#
# ---- original file header ----

# ---- original file header ----
#
# @summary
#       Quote and concatenate arguments for use in Bourne shell.
#
#    Each argument is quoted separately, and then all are concatenated
#    with spaces.  If an argument is an array, the elements of that
#    array is interpolated within the rest of the arguments; this makes
#    it possible to have an array of arguments and pass that array to
#    shellquote instead of having to specify each argument
#    individually in the call.
#    
#
Puppet::Functions.create_function(:'shellquote') do
  # @param args
  #   The original array of arguments. Port this to individually managed params
  #   to get the full benefit of the modern function API.
  #
  # @return [Data type]
  #   Describe what the function returns here
  #
  dispatch :default_impl do
    # Call the method named 'default_impl' when this is matched
    # Port this to match individual params for better type safety
    repeated_param 'Any', :args
  end


  def default_impl(*args)
    

    result = []
    args.flatten.each do |word|
      if word.length != 0 and word.count(Safe) == word.length
        result << word
      elsif word.count(Dangerous) == 0
        result << ('"' + word + '"')
      elsif word.count("'") == 0
        result << ("'" + word + "'")
      else
        r = '"'
        word.each_byte do |c|
          r += "\\" if Dangerous.include?(c)
          r += c.chr
        end
        r += '"'
        result << r
      end
    end

    return result.join(" ")
  
  end
end
