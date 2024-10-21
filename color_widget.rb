require 'pry'
require 'tk'
require './helpers.rb'

class Color
  attr_reader :red,:green,:blue
  def initialize *args
      case args[0]
      when String
        # format is "#RRGGBB", Tk likes it that way
        self.color = args[0]
      when Color # copy
        @red   = args[0].red
        @green = args[0].green
        @blue  = args[0].blue
        update_color_str
      else
        if args.length == 3
          @red, @green, @blue = *args 
          update_color_str
        else
          @red = @green = @blue = 0
          update_color_str
        end
      end
  end
  def to_s
    @color_s
  end
  def to_a
    [@red,@green,@blue]
  end
  def [] ind
    return self.to_a[ind]
  end
  def []= ind, value
    case ind
    when 0
      @red   = value
    when 1
      @green = value
    when 2
      @blue  = value
    end
    update_color_str
  end
  def color= color_str
    @red, @green, @blue = 2.downto(0).to_a.map{|n| ((color_str[1..-1].hex & (0xFF<<8*n)) >> 8*n)}
    @color_s = color_str
  end
  def update_color_str
    @color_s = sprintf("#%.2X%.2X%.2X",@red, @green, @blue) 
  end
  def red= red_val
    @red = red_val
    update_color_str
  end
  def green= green_val
    @green = green_val
    update_color_str
  end
  def blue= blue_val
    @blue = blue_val
    update_color_str
  end
end

class SingleColorChooser < TkFrame
  attr_accessor :base_color 
  attr_reader   :current_intensity
  def initialize parent, base_color, base_intensity=255
    super parent
    @base_color = Color.new(base_color) 
    @callbacks = [] 
    index = @base_color.to_a.index(0xFF)
    @current_color = Color.new
    @current_color[index] = base_intensity 
    @intensity_var = TkVariable.new(@current_color.to_s)
    intensity_var = @intensity_var # make a local reference, so we can close over it below
    @current_intensity = base_intensity

    @panel_height = 200
    panel_height = @panel_height 

    color_slider_panel = TkFrame.new(self) 
    fixed_color_panel = TkFrame.new(color_slider_panel) 
    color_panel = TkFrame.new(fixed_color_panel) do
      #panel just to show the color
      width 41
      height panel_height
    end
    color_panel.height scale_to_x(@current_intensity, @panel_height)
    color_panel.background = @current_color.to_s
    color_panel.pack :side=>"bottom" #pack into fixed frame, glue to bottom
    slider = TkScale.new(color_slider_panel) do
      orient 'vertical'
      label ''
      length panel_height
      from 255
      to 0
      variable intensity_var
      showvalue false # don't display number on spin box
    end
    slider.set @current_intensity
    spin_box = TkSpinbox.new(self) do
      to 255
      from 0
      width 4
      justify 'right'
      # we can't just directly link it to a variable
      # since we'd like to be able to edit the value and not
      # have it take effect until we press enter
      # this keeps thins from jupming around on you
      spinbox_function = lambda{ #function that gets called when
        # we want to process the event
        intensity_var.value = self.get #this is the forward linkage to the variable
      }
      command { |ev| # ev has current value, direction pressed, and a reference to the widget itself
        # take care of the up and down buttons
        spinbox_function.call
      }
      ["Return","KP_Enter"].each do |key| 
        # to allow you to enter with keypad
        bind(key){
          spinbox_function.call unless self.get =~ /[\D]/ #unless has non-digit characters
        }
      end
      # now do the linkage from the variable back to the 
      intensity_var.trace("w"){ |var|
        self.set var.value #command does not get executed again, so there's no infinite mutual recursion 
      }
    end
    spin_box.set @current_intensity
    @intensity_var.trace("w") do |intensity_var| # when variable is written, run our block
      # we change the appearance of our color panel
      @current_intensity = intensity_var.value.to_i
      current_intensity = intensity_var.value
      intensity_scaled = scale_to_x(intensity_var.value.to_i, @panel_height)
      color_panel.height intensity_scaled # intensity is 0-255, but panel height is different 
      index = @base_color.to_a.index(0xFF)
      new_color = Color.new
      new_color[index] = intensity_var.value
      color_panel.background new_color.to_s
      notify_change @current_intensity
    end
    #these two pack side by side in their own frame
    fixed_color_panel.pack   :side=>'left',   :fill=>'y'
    slider.pack        :side=>'left'
   
    #pack the frame containing both the color display and  
    color_slider_panel.pack
    spin_box.pack      :side=>'bottom', :fill=>'x'
  end
  def current_intensity= intensity
    return if intensity > 255
    return if intensity < 1
    @current_intensiy = intensity.to_i
    @intensity_var.value = intensity.to_i
  end
  def scale_to_x val, scale
    val*scale/255
  end
  def command *args, &block
    unless args.length == 0
      @callbacks << args[0].to_proc
    else
      @callbacks << block
    end
  end
  def notify_change intensity
    @callbacks.each{|callback| callback.call @current_intensity}
  end
end


class CompositingPreview < TkFrame
  attr_reader :color
  def initialize parent, color="#FFFFFF"
   super parent 
   background '#000000'
   @color = color
   @photo_image = TkPhotoImage.new
   @photo_image.height = 50
   @photo_label = TkLabel.new(self)
   @photo_label.image @photo_image
   @photo_label.pack :fill=>'both', :expand=>'1'

   @photo_label.bind("Configure") { |ev| # resize events
      @photo_image.width = ev.width-2
      @photo_image.height = ev.height-2
      update_widget
   }
  end
  def update_widget
    line_color = Color.new "#000000" 
    0.upto(@photo_image.width-1) do |x|
      next unless x%3==0 #only do every 3rd one, draw lines 3 wide below
      [0,1,2].each{|i| 
        line_color[i] += @color[i] 
        line_color[i] = 255 if line_color[i] > 255
      }
      @photo_image.put(line_color.to_s, :to=>[x,0,x+3,@photo_image.height-1])
    end
  end
  def set_color color
    @color = color
    update_widget
  end
end
class ColorChooser < TkFrame
  # color choosing widget with fancy features
  # send outs notifications to anyone who registers by ColorChooser::command plus a block
  # callback should have one parameter, the new color
  def initialize parent, red=255,green=255,blue=255
    super parent
    @color = Color.new(red,green,blue)
    @callbacks = []
    #somehow, if a block exists it will automatically be passed to the parent
    # must be some metaprogramming magic going on
    width 900
    height 200 
    #background @color
    @red_chooser    =  SingleColorChooser.new self, "#FF0000", @color.red  
    @green_chooser  =  SingleColorChooser.new self, "#00FF00", @color.green 
    @blue_chooser   =  SingleColorChooser.new self, "#0000FF", @color.blue
    
    @color_preview_panel = TkFrame.new(self){
      height 50
      width 50
    }
    @red_chooser.command()  {|intensity| @color.red = intensity; update_color }
    @green_chooser.command(){|intensity| @color.green = intensity; update_color }
    @blue_chooser.command() {|intensity| @color.blue = intensity; update_color }
    
    @brightness_var = TkVariable.new(50)
    brightness_var = @brightness_var
    @brightness_slider = TkScale.new(self) do
      orient 'vertical'
      from 100 
      to 0
      set 50
      showvalue false # don't display number on spin box
      variable brightness_var
    end

    mid_frame = TkFrame.new(self) # need to group some stuff

    brightness_sb = TkSpinbox.new(mid_frame) do
      from 0
      to 100
      width 3 
      set 50
      spinbox_function = lambda{
        brightness_var.value = self.get
      }
      command { |ev| spinbox_function.call }
      ["Return","KP_Enter"].each do |key| 
        # to allow you to enter with keypad
        bind(key){
          spinbox_function.call unless self.get =~ /[\D]/ #unless has non-digit characters
        }
      end
    end
    # link the slider back to the spinbox 
    brightness_var.trace("w"){ |var|
      brightness_sb.set var.value 
    }
    brightness_var.trace("w"){|var| update_brightness } 

    @compositing_preview = CompositingPreview.new self, @color

    @hex_entry_var = TkVariable.new(@color.to_s)
    @hex_entry = TkEntry.new(mid_frame) do
      width 4
    end
    @hex_entry.textvariable @hex_entry_var
    ["Return","KP_Enter"].each do |key| 
      # to allow you to enter with keypad
      @hex_entry.bind(key){
        @color.color = @hex_entry_var.value
        update_color
      }
    end
    
    apply_button = TkButton.new(mid_frame) do
      text "Apply"
      f = TkFont.new :family=>'Ariel', :size=>'8'
      font f
      height 1
      pady 0
    end
    apply_button.command{ notify_change }
    @hex_entry.pack    :side=>'top', :fill=>'x'#, :in=>mid_frame
    brightness_sb.pack :side=>'top', :fill=>'x'#, :in=>mid_frame
    apply_button.pack  :side=>'top', :fill=>'x' 
    
    row = (0..50).each
    @red_chooser.grid         :column=>0, :row=>row.peek
    @green_chooser.grid       :column=>1, :row=>row.peek
    @blue_chooser.grid        :column=>2, :row=>row.peek
   
    @brightness_slider.grid    :column=>3, :row=>row.next, :sticky=>'ns'

    @color_preview_panel.grid :column=>0, :row=>row.peek, :sticky=>'snew'
    mid_frame.grid            :column=>1, :row=>row.peek, :sticky=>'nsew'
    @compositing_preview.grid :column=>2, :row=>row.next, :columnspan=>2, :sticky=>'snew'
    cols, rows = grid_size
    0.upto(cols-1).map{ |col| TkGrid.columnconfigure self, col, :weight=>1 } 
    0.upto(rows-1).map{ |row| TkGrid.rowconfigure    self, row, :weight=>1 }

    update_color
  end
  def update_brightness
    # the brightness has changed
    current_brightness = calculate_brightness
    if @brightness_var.value.to_i != current_brightness
      color = Color.new(@color)
      begin
        if @brightness_var.value.to_i < current_brightness 
          [0,1,2].each{|i| color[i] -= 1 unless color[i] <= 0}
        else
          [0,1,2].each{|i| color[i] += 1 unless color[i]>=255}
        end
        proposed_brightness = color.to_a.reduce(:+)*100/(255*3)
      end while proposed_brightness != @brightness_var.value.to_i
      @color = color
      update_color
    end
  end
  def calculate_brightness
    brightness = @color.to_a.reduce(:+) #sum the color components
    brightness*100/(255*3)
  end
  def update_color
    new_color = Color.new
    @red_chooser.current_intensity = @color.red
    @green_chooser.current_intensity = @color.green
    @blue_chooser.current_intensity = @color.blue
 
    @color_preview_panel.background @color.to_s
    @hex_entry_var.value = @color.to_s
    @compositing_preview.set_color @color
    scaled_brightness = calculate_brightness
    @brightness_var.value = scaled_brightness
  end
  def command &block
    @callbacks << block
  end
  def notify_change 
    @callbacks.each{ |callback| callback.call @color.to_s}
  end
  def get_composite_color
    @color
  end
end

if $0==__FILE__
  root = TkRoot.new
  root.bind("x") { exit }
  root.title "Color Chooser Widget"
  c = ColorChooser.new(root,255,200,125)
  c.pack
  Tk.mainloop
end
