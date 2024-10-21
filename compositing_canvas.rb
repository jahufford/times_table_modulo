require 'pry'
require './helpers.rb'
require 'tkextlib/tkimg/png'
class CompositingCanvas
  attr_accessor :image
  def initialize width=500,height=500
    @image = TkPhotoImage.new 
    @image.width = width
    @image.height = height
  end
  def save filename
    #@image.write filename, :format=>"gif"
    @image.write filename, :format=>"png"
  end
  def height
    @image.height
  end
  def height= h
    @image.height = h
  end
  def width
    @image.width
  end
  def width= w
    @image.width = w
  end
  def putpixel image, x, y, color, composite=false
    if composite
      c = []
      2.downto(0) do |n|
         #c << (   (color[1..-1].hex & (0xFF<<(n*8))  ) >> (n*8)   )
         c << ((color[1..-1].hex & (0xFF<<8*n)) >> 8*n)
      end
      p = image.get(x,y) 
      p = c.myzip(p){|a,b| (a+b > 0xFF)? 0xFF : a+b}
      image.put(sprintf("#%.2X%.2X%.2X",p[0],p[1],p[2]), :to=>[x,y])
    else
      image.put(color, :to=>[x, y])
    end
  end
  def clear
    @image.put("#000000",:to=>[0,0,width,height])
  end
  def line x1, y1, x2, y2, color, composite=false
    del_x = x2 - x1
    del_y = y2 - y1
    if del_x==0 and del_y==0
      return
    end
    if del_y.abs <= del_x.abs
      if x2<x1
        x1, x2 = x2, x1
        y1, y2 = y2, y1
      end
      m = del_y.to_f/del_x
      x1.upto(x2) do |x|
        y = m*(x-x1)
        begin
          x = @image.width-1 if x>=@image.width
          x = 0 if x < 0
          yy = y1+y.round
          yy = 0 if yy<0
          yy = @image.height-1 if yy>=@image.height
          putpixel(@image, x, yy,color, composite)
        rescue Exception => e
          binding.pry
        end
      end
    else
      flag = false
      if y2<y1
        y1, y2 = y2, y1
        flag = true
      end
      m = del_x.to_f/del_y
      if del_y == 0 
        binding.pry
      end
      y1.upto(y2) do |y|
        x = (m)*(y-y1)
        putpixel(@image,x2+x.round, y.to_i, color,composite) if flag
        putpixel(@image,x1+x.round, y.to_i, color,composite) unless flag
      end
    end
  end
  def ellipse image, x, y, x_radius, y_radius, color
    xs = (-x_radius)..(x_radius)
    ys = xs.step(1).map{|xc|
      # gnarly one liner, from equation for an  ellipse x^2/a^2  + y^2/b^2 = 1
      # x is half the width of the ellipse (the x_radius)
      # y is half the heigh of the ellipse (the y_radius)
      Math.sqrt(((y_radius*y_radius)*(1.0 - ((xc.to_f*xc)/(x_radius.to_f*x_radius)))).abs).round
    }
    # the above was done around 0, need to translate now
    xs = xs.to_a.map{|xx| xx+x}
    # we have to hold off a bit to translate the y's since, we need to mirror it around the x-axis
    # due to the two roots of the above equation
    # now we have all the x coordinates is xs, and untranslated y's in ys
    # zip them together into an array of xy pairs, you could map those into little hashes for easier readability (first[:y] vs first[1])
    # then draw lines between them
    # standard zip
    xs.zip(ys).reduce{|first,second|
      line(image, first[0], y+first[1].to_i, second[0],y+second[1], color)
      line(image, first[0], y-first[1].to_i, second[0],y-second[1], color)
      second
    }
  end
end

