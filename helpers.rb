def print_callstack caller
  # caller gets filled up with functions from pry or tk
  # this only displays functions from our directory
  # will need to expand to handle a directory structure
  puts caller.select {|p| d=p.split('/')[0..-2].join('/'); d.empty? or d==Dir.getwd}
end

class Array
  def myzip(var)
    result = []
#    0.upto(self.size) do |i|
#      result << yield(self[i],var[i])
#    end
    if block_given?
      self.zip(var){|x,y| result << yield(x,y)}
    else
      result = self.zip(var)
    end
    result
  end
  def unzip
    result_one = []
    result_two = []
    self.each{|i| one,two=yield(i); result_one<<one; result_two<<two} 
    [result_one, result_two]
  end
end
