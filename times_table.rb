require 'tk'
require 'pry'
#require 'rmagick'
require 'gifanime'
require './compositing_canvas.rb'
require './helpers.rb'
# point helper class, y is increasing downwards, while complex numbers increase upwards 
class Point
  attr_accessor :x, :y
  def initialize *arg 
    case arg.length
    when 2 # when 2 arg's are given, they are x and y
      @x = arg[0].to_i
      @y = arg[1].to_i
    when 1 
      case arg[0]
      when Complex #build a point from a complexe number
        @x = arg.real.to_i
        @y = -arg.imag.to-i #need the complexe conjugate here to flip it vertically
      when Point
        @x = arg.x.to_i
        @y = arg.y.to_i
      end
    else
      STDERR.puts "Wrong number of argumengs given. Expected 1 or 2, received #{arg.length}"
    end
  end
  def + arg
    case arg
    when Complex
      Point.new(@x+arg.real, @y+arg.imag) 
    when Point
      Point.new(@x+arg.x, @y+arg.y)
    end
  end
end
class TimesTable
  attr_reader :canvas
  attr_accessor :compositing 
  attr_accessor :buildup_animation, :buildup_animation_length
  attr_accessor :animation_row_start, :animation_row_stop
  attr_accessor :animation_modulo_start, :animation_modulo_stop
  attr_accessor :save_animation_to_file
  #Point = Struct.new(:x, :y) { |p_class|
  #}
  def self.attr_notify *syms, &block
    syms.each do |sym|
      unless self.instance_methods(true).include? sym
        attr_reader sym
        define_method("#{sym.to_s}=") do |val| # a little bit of meta-magic. I can have a callback ran every time the setter gets called
          #puts "attr_notify #{sym.to_s}"
          instance_variable_set("@#{sym.to_s}", val)
          self.instance_exec val, &block
        end 
      else
        raise "Method \"#{sym.to_s}\" already defined"
      end
    end
  end
  #attr_notify :row,:modulo,:zoom,:line_color { update } #update will be called when any of these are changed 
  attr_accessor :row,:modulo,:zoom,:line_color
  attr_notify :background_color { |color| @canvas.background = color unless color.empty?}
  def initialize 
    @active = false
    @buildup_animation = false
    @buildup_animation_length = 5
   # animation defaults 
    @animation_row_start = 2
    @animation_row_stop     = 10
    @animation_modulo_start = 10
    @animation_modulo_stop  = 10
    @save_animation_to_file = false
    @modulo = 20 # 
    @zoom = 125
    @row = 2
    @start = []
    @progress_callbacks = [] # this is an array that stores progress callbacks.
    @progress_reset_callbacks = []
    @compositing = false
    @line_color = "#FFFFFF"
    @marker_fill = "orange"
    @marker_outline = "green"
    @marker_radius = 2
    @background_color = "blue"
    @abort = false
    @canvas = TkCanvas.new
    @canvas.width = 700 
    @canvas.height = 700
    @canvas.background @background_color 
    @center = Point.new(@canvas.width/2,@canvas.height/2)
    @canvas.bind("1"){ |ev| 
      @start = [ev.x, ev.y]
    }
    # MouseWheel events don't work, 
    # instead they are button 4 and button 5
    prev_time = Time.now
    @canvas.bind("Button-4") {
      # button 4 is up
      delta_t = Time.now-prev_time
      if delta_t > 0.200 
        self.zoom += 1 # use the self form so the callback gets called
      else
        accel_amt = 1/(delta_t*10)
        accel_amt = accel_amt>10 ? 10 : accel_amt
        self.zoom += accel_amt.to_i unless @zoom-accel_amt < 1 
      end
      update
      prev_time = Time.now
    }
    @canvas.bind("Button-5") {
      # button 5 is down
      delta_t = Time.now-prev_time
      if delta_t > 0.200 
        self.zoom -= 1 unless @zoom < 2# use the self form so the callback gets called
      else
        accel_amt = 1/(delta_t*10)
        accel_amt = accel_amt>10 ? 10 : accel_amt # max acceleration
        self.zoom -= accel_amt.to_i unless @zoom-accel_amt < 2 
      end
      prev_time = Time.now
      update
    }
    puts "#{@canvas.width}, #{@canvas.height}"
    @c_canvas = CompositingCanvas.new @canvas.width, @canvas.height
    compositing_image = TkcImage.new(@canvas,@canvas.width/2+1,@canvas.height/2+1, :image=>@c_canvas.image)

    @c_canvas.clear
    @canvas.bind("Configure"){ |ev|
      # resize events, reset the center of my picture
      @center.x = ev.width/2
      @center.y = ev.height/2
      compositing_image.coords = [@center.x, @center.y]
      @c_canvas.height = ev.height
      @c_canvas.width  = ev.width
      update
    }
  end
  def abort
    @abort = true
    progress_done
  end
  def generate_points
    rotator = Complex.polar(1,2*Math::PI/@modulo)
    #@circle_points = 0.upto(@modulo-1).map{|n| ((@modulo/2).floor - n) % @modulo} # in my picture, 0 is at 9 o'clock, but with complex arithmetic, 0 is at 3o'clock, shift some stuff around
    @circle_points = 0.upto(@modulo-1).map{|n| @zoom*(rotator**n)} # gets points on circle, with complex numbers
      .map{|n| Complex(-n.real,n.imag)} # we want 0 at 9 o'clock, so we need to flip horizontally
    @numeral_text_points = @circle_points.map{ |p| (p/p.abs)*15.0 + p} # normalize then expand radially, has to a float, has to a float
    @circle_points.map!{|c| @center+c.conjugate} # map into canvas coordinates, flip the imaginary part, screen y increases down, while complex numbers increase up
    @numeral_text_points.map!{|n| @center+n.conjugate}
  end
    # actually make the lines
    # @circle_points contains x y on a circle
  def draw_times_table
    @abort = false
    # little circle marks representing the numbers line our our big circle
    @numeral_markers ||= []
    @numeral_markers.each{|marker| marker.delete}
    if @modulo < 201
      @numeral_markers = @circle_points.map{|n| TkcCircle.new(@canvas, n.x,n.y,@marker_radius,:fill=>@marker_fill, :outline=>@marker_outline)}
    end

      @numeral_text_item ||= []
      @numeral_text_item.each{|i| i.delete}
    if @modulo < 201
      @numeral_text_item = @numeral_text_points.map.with_index{|p,index| 
        TkcText.new(@canvas, p.x, p.y,:text=>index.to_s,:fill=>@line_color)
      } 
    end

    @times_table_lines ||= []
    @times_table_lines.each{ |line| line.delete }
    @times_table = 0.upto(@modulo-1).map{|n| [n, @row*n % @modulo]} # now I have a set of pairs representing a times table
    @c_canvas.clear 
    progress_start @times_table.size
    if @compositing
      if @buildup_animation
         #buildup_animation_count = 1
         filename = make_filename
         begin
           # make a directory with the same name as the file 
           Dir.mkdir filename 
         rescue
         end 
         #s = "./"+filename+"/"+filename+".gif"
         #gifanime = Gifanime.new("./"+filename+"/"+filename+".gif",:delay=>1)
      end 
      buildup_animation_count = "0"*@modulo.to_s.length
      @times_table.each { |line_beginning, line_ending|
        @c_canvas.line(@circle_points[line_beginning].x, @circle_points[line_beginning].y, @circle_points[line_ending].x, @circle_points[line_ending].y,@line_color,true)
        emit_progress
        if @buildup_animation
          buildup_animation_count.next!
          framename = filename+"_"+buildup_animation_count+".png"
          #framename = buildup_animation_count+".gif"
          #framename = buildup_animation_count+".png"
          framename_path = "./"+filename+"/"+framename
          @c_canvas.save(framename_path)
          #gifanime.add(framename_path)      
        end
        break if @abort
      }
      if @buildup_animation
        #ffmpeg -i mod_10_row_2_zoom_300_color_#FFFFFF_%02d.png -c:v libx264 -r 30 out.mp4
        base_dir = Dir.getwd
        Dir.chdir("./#{filename}")
        #system("ffmpeg -y -framerate #{@modulo/@buildup_animation_length} -i #{filename}_%0#{@modulo.to_s.length}d.png -c:v libx264 -r 30 #{filename}.mp4")
        # this one works system("ffmpeg -y -framerate #{@modulo/@buildup_animation_length} -i #{filename}_%0#{@modulo.to_s.length}d.png -vf scale=-2:1080,format=yuv420p -c:v libx264  -profile:v high -preset slow -b:v 1000k -maxrate 1000k -bufsize 1000k -threads 0 -crf 1 -c:a libfdk_aac -b:a 128k -r 60 #{filename}.mp4")
        system("ffmpeg -y -framerate #{@modulo/@buildup_animation_length} -i #{filename}_%0#{@modulo.to_s.length}d.png -vf scale=-2:1080,format=yuv420p -c:v libx264  -profile:v high -preset slow -b:v 1000k -maxrate 1000k -bufsize 1000k -threads 0 -crf 1 -c:a libfdk_aac -b:a 128k -r 60 base_video.mp4")
        #ffmpeg -i input.mp4 -vf scale=-2:1080,format=yuv420p -c:v libx264 -profile:v high -preset slow -b:v 1000k -maxrate 1000k -bufsize 1000k -threads 0 -c:a libfdk_aac -b:a 128k output.mp4
        #system("ffmpeg -y -framerate #{@modulo/@buildup_animation_length} -i #{filename}_%0#{@modulo.to_s.length}d.png -c:v mpeg4 -r 30 #{filename}.mp4")
        #system("ffmpeg -y -i #{filename}_%0#{@modulo.to_s.length}d.png -c:v mpeg4  #{filename}.mp4")
        #system("ffmpeg -y -framerate #{@modulo/5} -i #{filename}_%0#{@modulo.to_s.length}d.png -c:v libx264 -vf fps=60 #{filename}.mp4")
        
        # loop the last frame
        system("ffmpeg -y -loop 1 -i #{filename}_#{@modulo}.png -t 5 -vf scale=-2:1080,format=yuv420p -c:v libx264 -profile:v high -preset slow -b:v 1000k -maxrate 1000k -bufsize 1000k -threads 0 -crf 1 -c:a libfdk_aac -b:a 128k -r 60 last_frame_loop.mp4")
        # concatenate the two
        system("ls base_video.mp4 last_frame_loop.mp4 | ruby -ne 'puts \"file \#{$_}\"' | ffmpeg -y  -f concat -i - #{filename}.mp4")
        # do overlay, extend the last frame for 15 seconds
        ##system("ffmpeg -y -f lavfi -i nullsrc=s=932x1080:d=#{@modulo/@buildup_animation_length + 5}:r=60 -i #{filename}.mp4 -filter_complex \"[0:v][1:v]overlay[video]\" -map \"[video]\"  -codec:a copy -shortest c.mp4")
        #overlay_height = (@c_canvas.width*1080.0/@c_canvas.height).ceil
        #overlay_height = overlay_height+1 if overlay_height%2==1 #increase to the largest even number
        #system("ffmpeg -y -f lavfi -i nullsrc=s=#{overlay_height}x1080:d=#{@modulo/@buildup_animation_length + 5}:r=60 -i #{filename}.mp4 -filter_complex \"[0:v][1:v]overlay[video]\" -map \"[video]\"  -codec:a copy -shortest c.mp4")

        # clean up
        #
        # delete loop vid, and then intermediate png's, but save last png(final image)
        system("mv #{filename}_#{@modulo}.png #{filename}.png")
        system("rm #{filename}_*.png")
        system("rm base_video.mp4")
        system("rm last_frame_loop.mp4")
        
        Dir.chdir(base_dir)
#        gifanime.generate! # => generates the animatied gif
#        GC.start
      end
      else
        @times_table_lines = @times_table.map{ |line_beginning, line_ending|
          TkcLine.new @canvas, @circle_points[line_beginning].x, @circle_points[line_beginning].y, @circle_points[line_ending].x, @circle_points[line_ending].y,:fill=>@line_color
        }
      end
  end
  def animate 
    # we do the animation by reading the setting
    (@animation_row_start..@animation_row_stop).each{ |row|
      var = false
      while(var == false) do
        Tk.update
      end
      Tk.after(500) { var = true } 
      @row = row
      puts row
      self.update
      Tk.update
    } 
  end
  def make_filename
    "mod_#{@modulo}_row_#{@row}_zoom_#{@zoom}_color_#{@line_color}"
  end
  def save
    if @compositing
      # construct a name with enough info to recreate the image
      name = "./pics/" + make_filename + ".gif"
      name = "./pics/mod_#{@modulo}_row_#{@row}_zoom_#{@zoom}_color_#{@line_color}.gif"
      @c_canvas.save name
    else
      Tk::messageBox :type=>'ok', :icon=>"info", :title=>"Times Modulo",
                     :message=>"Sorry, I can't do that for you yet. You can only save composited images"
    end
  end
  def update
    if @active
      generate_points
      draw_times_table
    end
  end
  def on
    @active = true
  end
  def off
    @active = false
  end
  def progress_callback &block
    @progress_callbacks << block
  end
  def progress_reset &block
    @progress_reset_callbacks << block
  end
  def progress_start num_of_steps
    # num_of_step is the number of interations that 
    # you're trying to emit progress from
    @progress_num_of_steps = num_of_steps
    @current_step = (1..num_of_steps).each #create enumerator
    @current_progress = 0 
    @progress_reset_callbacks.each {|callback| callback.call(num_of_steps)}
  end
  def progress_done
    @progress_callbacks.each{|callback| callback.call(0)}
  end
  def emit_progress
    # this is called each iteration that you're adding a progress
    # bar to. It only calls the callback if progress has been made
    # between 1 and 100
    #progress = @current_step.next*100/@progress_num_of_steps  
    progress = @current_step.next  
    if progress != @current_progress
      @progress_callbacks.each{|callback| callback.call(progress)}
      #Tk.do_one_event
      @current_progress = progress
    end
    if @current_progress == @progress_num_of_steps
      progress_done
      #@progress_callbacks.each{|callback| callback.call(0)}
    end
  end
end


class TkcCircle < TkcOval
  def initialize parent, x, y, radius, *args
    super parent, x-radius, y-radius, x+radius,y+radius, *args 
  end
end

if __FILE__==$0
  root = TkRoot.new { title "Times Table Tester" }
  root.bind("x"){exit}
  t = TimesTable.new
  t.on
  x = 1
  var = TkVariable.new 
  var.trace("w") { puts "hi"}  
  button = TkButton.new(root){text "Line color"
    command{
      t.background_color = Tk::chooseColor
    }
  }
  button = TkButton.new(root){text "Zoom"
    command{ 
      t.zoom += 1;
      binding.pry 
    }
  }
  button.pack :side=>"bottom"
  t.canvas.pack :in=>root, :fill=>"both", :expand=>'1'
  Tk.mainloop
end
