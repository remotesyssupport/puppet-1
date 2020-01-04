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
#   Split a string variable into an array using the specified split regexp.
#
#  Usage:
#
#    $string     = 'v1.v2:v3.v4'
#    $array_var1 = split($string, ':')
#    $array_var2 = split($string, '[.]')
#    $array_var3 = split($string, '[.:]')
#
#$array_var1 now holds the result ['v1.v2', 'v3.v4'],
#while $array_var2 holds ['v1', 'v2:v3', 'v4'], and
#$array_var3 holds ['v1', 'v2', 'v3', 'v4'].
#
#Note that in the second example, we split on a string that contains
#a regexp meta-character (.), and that needs protection.  A simple
#way to do that for a single character is to enclose it in square
#brackets.
#
Puppet::Functions.create_function(:'split') do
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
    

  raise Puppet::ParseError, ("split(): wrong number of arguments (#{args.length}; must be 2)") if args.length != 2

  return args[0].split(Regexp.compile(args[1]))
  
  end
end
