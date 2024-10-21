# program that draws out times tables by modulus around a circle. Makes cool pictures.
# see the mathologer video about it
# https://www.youtube.com/watch?v=qhbuKbxJsk8
# uses ffmpeg to output videos of table being drawns
require 'ap' #awesome print
require 'pry'
require 'tk'
require './times_table.rb'
require './color_widget.rb'
require './helpers.rb'

class Animation
  attr_accessor :current_frame
  def initialize &block
    @timer = TkTimer.new{ draw }
    @timer.loop_exec = -1 # loop continuously
    @timer.set_interval(100) #default
    @current_frame = 0
    @save = false
    instance_eval &block if block_given?
  end
  def eigen
    class << self
      self
    end
  end
  def set_save filename
    @filename = filename
    @save = true
    begin
      Dir.mkidr filename
      Dir.chdir "./#{filename}"
    rescue
    end
  end
  def draw
    @delta_t = Time.now - @prev_time
    @prev_time = Time.now
    if @draw_func
      instance_eval &@draw_func
      if @save

      end
    end
    @current_frame += 1
  end
  def draw_func &block
    @draw_func = block
  end
  def save_frame

  end 
  def start frame = 0, &block
    @current_frame = frame
    instance_eval &block if block_given?
    save_frame
    @prev_time = Time.now
    @timer.start
  end
  def end_func &block
    @end_func = block
  end
  def stop
    @timer.stop
    @end_func.call
    @current_frame = 0
  end 
  def pause
    @timer.stop
    #don't reset current frame
  end
  def continue
    @timer.start
  end
  def running?
    @timer.running?
  end
  def set_interval interval
    @timer.set_interval interval
  end
end

$app_name = "TimesModulo"
def about_box
  about_box = TkToplevel.new do
    title "About #{$app_name}" 
  end
  text = TkLabel.new(about_box) do
    str = <<-END
    Wrap around times table!
    Draws pretty pictures. Yay!
    END
    text str
    width '30'
  end
  ok_b = Tk::Tile::Button.new(about_box){ text "Ok"; command proc{about_box.destroy }}
  ok_b.focus
  ok_b.bind("Return") { ok_b.invoke }
  text.pack :side =>'top',    :padx=>'15', :pady=>'5'
  ok_b.pack :side =>'bottom', :pady=>'5'
end

root = TkRoot.new
#w = root.winfo_screenwidth/2
#h = root.winfo_screenheight

#root['geometry'] = "#{w}x#{h}+0+0"
root.attributes['zoomed'] = 1;
TkOption.add '*tearOff', 0
menubar = TkMenu.new root  do
  file= TkMenu.new self do
    add :command, :label=>'Foo', :command=>proc{puts "foo"}
    add :command, :label=>'Exit', :command=>proc{exit}
  end
  help = TkSysMenu_Help.new(self) do
    #add :command, :label=>'About', :command=>method(:about_box).to_proc
    add :command, :label=>'About', :command=>proc{ about_box }
  end
  add :cascade, :menu=>file, :label=>"File"
  add :cascade, :menu=>help, :label=>"Help"
end
#help_menu = TkSysMenu_Help.new(self) do
#  add :command, :label=>'About', :command=>proc{about_box}
#end
#menubar.add :cascade, :menu=>help_menu, :label=>'About'
root.menu = menubar
root.title = $app_name
# content pane is a container to hold the controls and the 
# generated picture. Looks long but it's just the layout and some glue code
content_pane = TkFrame.new root do
  times_table = TimesTable.new
  times_table.modulo = 10
  times_table.row    = 2
  times_table.zoom   = 300
  times_table.compositing = false
  controls_frame = TkFrame.new self do
    spacer = TkFrame.new(self){ height 20; width 0}
    modulo_label = TkLabel.new(self) {text "Modulo:"}
    modulo_var = TkVariable.new(times_table.modulo)
    modulo_max = 10000
    modulo_sb = TkSpinbox.new(self){ 
      #textvariable modulo_var
      to modulo_max
      from 0
      width 4 # 4 characters wide
      justify 'right'
      set times_table.modulo
      callback = lambda { 
        modulo_var.value = self.value unless self.value.to_i == times_table.modulo # this links up to our slider
      }
      command { |button| #this gets called when the up or down arrows are pressed 
        callback.call() 
      }
      bind("Return"){ # this gets called when you're editing with the key board and you press enter
        callback.call
      }
      bind("KP_Enter"){ |ev|
        callback.call
      }
    }
    modulo_var.trace("w"){ |var| 
      modulo_sb.set var.value unless modulo_sb.get == var.value
      unless (modulo_sb.get=~/[\D]/ || 
              modulo_sb.get.to_i==0 || #unless it contains a non-digit character or is zero
              times_table.modulo == var.value.to_i ) # prevent times_table update from being called twice
        times_table.modulo = var.value.to_i
        times_table.update
      end
    }
    modulo_sl = TkScale.new(self) {
      orient 'horizontal'
      label=""
      length 150
      from 1.0
      to modulo_max
      showvalue false
      variable modulo_var
      #command{|val| times_table.modulo = get.to_i}
    }
    modulo_sl.bind("Button-4") {
      modulo_var.value = times_table.modulo+1
    }
    modulo_sl.bind("Button-5") {
      modulo_var.value = times_table.modulo-1 unless times_table.modulo==1
    }
    row_label = TkLabel.new (self){text "Row:"}
    row_var = TkVariable.new(times_table.row)
    row_max = modulo_max
    row_sb = TkSpinbox.new(self){ 
      to times_table.modulo
      from 1 
      width 4 # 4 characters wide
      justify 'right'
      set times_table.row
      callback = lambda { 
        row_var.value = get.to_i
      }
      #callback = lambda { row_var.value get.to_i}
      command { |ev| callback.call }
      ["Return","KP_Enter"].each { |key|
         bind(key){callback.call }
      }
    }
    row_var.trace("w"){ |var|
      row_sb.set var.value unless row_sb.get == var.value
      unless row_sb.get=~/[\D]/ || row_sb.get.to_i==0 #unless it has non digit characters or is zero 
        times_table.row = row_sb.get.to_i     
        times_table.update
      end
    }
    row_sl = TkScale.new(self){
      orient 'horizontal'
      label=""
      length 150
      from 1; to times_table.modulo
      variable row_var 
      showvalue false
    }
    modulo_var.trace("w"){ |var|
      # limit the row spinbox and slider to a max of modulo. row 2 is the same as row 12
      # this makes it easier to use slider when modulo is at smaller values
      row_sb.to var.value.to_i
      row_sl.to var.value.to_i
    }

    zoom_label = TkLabel.new(self){text "Zoom:"}
    zoom_var = TkVariable.new times_table.zoom
    zoom_max = 500
    zoom_sb = TkSpinbox.new(self){
      textvariable zoom_var
      to zoom_max
      from 1
      width 4
      justify 'right'
      set times_table.zoom
      callback = lambda {
        times_table.zoom = get.to_i
        times_table.update
      }
      command {|ev| callback.call}
      bind("Return"){callback.call}
    }
    zoom_sl = TkScale.new(self){
      orient 'horizontal'
      label=""
      length 150
      from 1
      to zoom_max
      variable zoom_var
      showvalue false
      command{|val| times_table.zoom=val}
    }
    

    composite_label = TkLabel.new(self){text "Composite:"}
    composite_cb    = TkCheckButton.new(self){
      command proc{|p|
        if variable.value == '1'
          times_table.compositing = true
          times_table.update
        else
          times_table.abort
          times_table.compositing = false
          Tk.after(200){
            # not the most elegant way, but there's a thread
            # issue with calling update to keep the progress bar updated
            times_table.update
          }
        end
      }
    }

    line_color_b = TkButton.new(self){
      text "Line Color"
      command {
        new_color = Tk::chooseColor(:initialcolor=>times_table.line_color)
        unless new_color.empty?
          times_table.line_color = new_color 
          times_table.update
        end
      }
    }
    line_color_widget = ColorChooser.new(self, "#FFFFFF")
    line_color_widget.command {|color|
      times_table.line_color = color
      times_table.update
    }
    line_color_sl = TkScale.new(self){
      orient 'horizontal'
    }
    background_color_b = TkButton.new(self){
      text "Background Color"
      command {
        new_color = Tk::chooseColor(:initialcolor=>times_table.line_color)
        times_table.background_color = new_color unless new_color.empty?
      } 
    }
    save_button = TkButton.new(self){
      text "Save Image"
      command {
        times_table.save
      }
    }
    progress_bar = Tk::Tile::Progressbar.new(self){ 
      orient 'horizontal'
      length 200
      mode 'determinate'
      maximum 100
    }
    times_table.progress_reset{ |steps|
      progress_bar.maximum steps
    }
    times_table.progress_callback{ |val|
      progress_bar.value val
      update
    }
    buildup_ani_frame = TkFrame.new(self)
    buildup_ani_l = TkLabel.new(buildup_ani_frame){text "Save Buildup\nAnimation:"}
    buildup_ani_cb = TkCheckButton.new(buildup_ani_frame){
      command proc{|p|
        if variable.value == '1'
          times_table.buildup_animation = true
        else
          times_table.buildup_animation = false
        end
      }
    }
    buildup_ani_sb = TkSpinbox.new(buildup_ani_frame){
      to 60
      from 0
      set times_table.buildup_animation_length
      width 2
      spinbox_function = proc{ 
        len = get.to_i
        times_table.buildup_animation_length = len
      }
      command &spinbox_function
      ["Return","KP_Enter"].each{|key| bind(key){ spinbox_function.call }}
    }
    buildup_ani_sec_l = TkLabel.new(buildup_ani_frame){ text "sec" }
    buildup_ani_l.pack     :side=>'left'
    buildup_ani_cb.pack    :side=>'left'
    buildup_ani_sb.pack    :side=>'left'
    buildup_ani_sec_l.pack :side=>'left'

    animation_controls = Tk::Tile::Labelframe.new(self) do
      text 'Animation Controls'
      width = 100
      height = 100
      row_start_l = TkLabel.new(self) {text 'Row Start'}
      row_start_sb = TkSpinbox.new(self){
        width 4
        to 10000
        from 2
        set times_table.animation_row_start
        spinbox_func = proc {
          times_table.animation_row_start = get.to_i
        }
        command {
          spinbox_func.call
        }
        ["Return","KP_Enter"].each { |key|
          bind(key){ spinbox_func.call }
        }
      }
      row_stop_l = TkLabel.new(self) {text 'Row Stop'}
      row_stop_sb = TkSpinbox.new(self){
        width 4
        to 10000
        from 2
        set times_table.animation_row_stop
        spinbox_func = proc {
          times_table.animation_row_stop = get.to_i
        }
        command {
          spinbox_func.call
        }
        ["Return","KP_Enter"].each { |key|
          bind(key){ spinbox_func.call }
        }
      }
      row_step_l = TkLabel.new(self) {text 'Row Step'}
      row_step_sb = TkSpinbox.new(self){
        width 4
        to 1000
        from 1
        set 1
      }
      modulo_start_l = TkLabel.new(self) {text 'Modulo Start'}
      modulo_start_sb = TkSpinbox.new(self){
        width 4
        to 10000
        from 1
        set times_table.animation_modulo_start
        spinbox_func = proc {
          times_table.animation_modulo_start = get.to_i
        }
        command {
          spinbox_func.call
        }
        ["Return","KP_Enter"].each { |key|
          bind(key){ spinbox_func.call }
        }
      }
      modulo_stop_l = TkLabel.new(self) {text 'Modulo Stop'}
      modulo_stop_sb = TkSpinbox.new(self){
        width 4
        to 10000
        from 10
        set times_table.animation_modulo_stop
        spinbox_func = proc {
          times_table.animation_modulo_stop = get.to_i
        }
        command {
          spinbox_func.call
        }
        ["Return","KP_Enter"].each { |key|
          bind(key){ spinbox_func.call }
        }
      }
      modulo_step_l = TkLabel.new(self) {text 'Modulo Step'}
      modulo_step_sb = TkSpinbox.new(self){
        width 4
        to 1000
        from 1
        set 1
      }
      length_label = TkLabel.new(self){ text 'Animation Length' }
      length_sb    = TkSpinbox.new(self){
        width 4
        to 60*5
        from 1
        set 5
      }
      save_animation_l = TkLabel.new(self){ text 'Save Animation' }
      save_animation_cb = TkCheckButton.new(self)
      current_row_l = TkLabel.new(self){ 
        text 'Current Row: '
        font  TkFont.new(:family=>"Helvetica", :size=>'8')
      }
      current_modulo_l = TkLabel.new(self){ 
        text 'Current Modulo: '
        font  TkFont.new(:family=>"Helvetica", :size=>'8')
      }

      animation = Animation.new()
      animation.draw_func {
        if @modulo_start == @modulo_stop # it's a row animation
          if @row_start+@current_frame*@row_step <= @row_stop
            times_table.row = @row_start+@current_frame*@row_step
            times_table.update
          else
            animation.stop 
          end
        elsif @row_start == @row_stop # it's a column animation
          if @modulo_start+@current_frame*@modulo_step <= @modulo_stop
            times_table.modulo = @modulo_start+@current_frame*@modulo_step
            save_animation_var
          else
            animation.stop 
          end
        else
          # it's a "line" animation delta_modulo/row_modulo
          if (@row_start+@current_frame*@row_step <= @row_stop) and (@modulo_start+@current_frame*@modulo_step <= @modulo_stop)
            times_table.row = @row_start+@current_frame*@row_step
            times_table.modulo = @modulo_start+@current_frame*@modulo_step
            times_table.update
          else
            animation.stop
          end
        end
        # while we're animating, update the current row and current modulo labels
        crt = (current_row_l.text).split(":")
        crt[1] = times_table.row.to_s  #" " + times_table.row.to_s        
        current_row_l.text crt.join(":")
  
        cmt = (current_modulo_l.text).split(":")
        cmt[1] = times_table.modulo.to_s  #" " + times_table.row.to_s        
        current_modulo_l.text cmt.join(":")
      }

      go_button = TkButton.new(self) {
        text "Go!"
        command { 
          if animation.running?
            animation.stop
            text "Go!"
          else
            animation.set_interval length_sb.get.to_i
            animation.end_func {
              go_button.text "Go!"
            }
            #times_table.abort
            #Tk.after(2000) {
            animation.start{
              @row_start = row_start_sb.get.to_i
              @row_stop  = row_stop_sb.get.to_i
              @row_step  = row_step_sb.get.to_i
              @modulo_start = modulo_start_sb.get.to_i
              @modulo_stop = modulo_stop_sb.get.to_i
              @modulo_step = modulo_step_sb.get.to_i
              if save_animation_cb.variable.value=="1"
                puts "save animation"
                save_name = "animation_"
                save_name << "rstart_#{@row_start}_rstop_#{@row_stop}_rstep_#{@row_step}_"
                save_name << "mstart_#{@modulo_start}_mstop_#{@modulo_stop}_mstep_#{@modulo_step}"
                save_name << "_color_#{times_table.line_color}"
                puts save_name
                animation.set_save save_name 
              end
              times_table.row = @row_start
              times_table.modulo = @modulo_start
            } 
            text "Stop"
          end
        }
      }
 
      row = (0..50).each # make enumerator  
      row_start_l.grid   :column=>0, :row=>row.peek, :sticky=>'w'
      row_start_sb.grid  :column=>1, :row=>row.next, :sticky=>'e'
      row_stop_l.grid    :column=>0, :row=>row.peek, :sticky=>'w'
      row_stop_sb.grid   :column=>1, :row=>row.next, :sticky=>'e'
      row_step_l.grid    :column=>0, :row=>row.peek, :sticky=>'w'
      row_step_sb.grid   :column=>1, :row=>row.next, :sticky=>'e'

      modulo_start_l.grid   :column=>0, :row=>row.peek, :sticky=>'w'
      modulo_start_sb.grid  :column=>1, :row=>row.next, :sticky=>'e'
      modulo_stop_l.grid    :column=>0, :row=>row.peek, :sticky=>'w'
      modulo_stop_sb.grid   :column=>1, :row=>row.next, :sticky=>'e'
      modulo_step_l.grid    :column=>0, :row=>row.peek, :sticky=>'w'
      modulo_step_sb.grid   :column=>1, :row=>row.next, :sticky=>'e'

      length_label.grid  :column=>0, :row=>row.peek, :sticky=>'w'
      length_sb.grid     :column=>1, :row=>row.next, :sticky=>'e'

      save_animation_l.grid   :column=>0, :row=>row.peek, :sticky=>'w'
      save_animation_cb.grid  :column=>1, :row=>row.next, :sticky=>'e'

      current_row_l.grid    :column=>0, :row=>row.peek, :sticky=>'w'
      current_modulo_l.grid :column=>1, :row=>row.next, :sticky=>'w'
      
      go_button.grid     :column=>0, :row=>row.next, :sticky=>'ew', :columnspan=>2 

      cols, rows = grid_size
      0.upto(cols-1).map{ |col| TkGrid.columnconfigure self, col, :weight=>1 } 
      0.upto(rows-1).map{ |row| TkGrid.rowconfigure    self, row, :weight=>1 }
    end
    ani_row_start_cb = TkCheckButton.new(animation_controls) 
  
    row = (0..50).each
    #spacer.grid             :column=>0, :row=>row.next, :sticky=>'n'
    modulo_label.grid       :column=>0, :row=>row.peek, :sticky=>"wn"
    modulo_sb.grid          :column=>1, :row=>row.next, :sticky=>"e"
    modulo_sl.grid          :column=>0, :row=>row.next, :sticky=>"ew", :columnspan=>2
    Tk::Tile::Separator.new(self){orient 'horizontal'}.grid :column=>0, :row=>row.next, :sticky=>'ew', :columnspan=>2, :pady=>'2'
    row_label.grid          :column=>0, :row=>row.peek, :sticky=>"wn"
    row_sb.grid             :column=>1, :row=>row.next, :sticky=>"e" 
    row_sl.grid             :column=>0, :row=>row.next, :sticky=>"ew", :columnspan=>2
    Tk::Tile::Separator.new(self){orient 'horizontal'}.grid :column=>0, :row=>row.next, :sticky=>'ew', :columnspan=>2, :pady=>'2'
    zoom_label.grid         :column=>0, :row=>row.peek, :sticky=>"w"
    zoom_sb.grid            :column=>1, :row=>row.next, :sticky=>"e"
    zoom_sl.grid            :column=>0, :row=>row.next, :sticky=>"ew", :columnspan=>2
    Tk::Tile::Separator.new(self){orient 'horizontal'}.grid :column=>0, :row=>row.next, :sticky=>'ew', :columnspan=>2, :pady=>'2'
    composite_label.grid    :column=>0, :row=>row.peek, :sticky=>"w"
    composite_cb.grid       :column=>1, :row=>row.next, :sticky=>"e"
    Tk::Tile::Separator.new(self){orient 'horizontal'}.grid :column=>0, :row=>row.next, :sticky=>'ew', :columnspan=>2, :pady=>'2'
    line_color_b.grid       :column=>0, :row=>row.next, :sticky=>"ew", :columnspan=>2
    line_color_widget.grid  :column=>0, :row=>row.next, :sticky=>"w",  :columnspan=>2
    Tk::Tile::Separator.new(self){orient 'horizontal'}.grid :column=>0, :row=>row.next, :sticky=>'ew', :columnspan=>2, :pady=>'2'
    background_color_b.grid :column=>0, :row=>row.next, :sticky=>"ew", :columnspan=>2
    Tk::Tile::Separator.new(self){orient 'horizontal'}.grid :column=>0, :row=>row.next, :sticky=>'ew', :columnspan=>2, :pady=>'2'
    save_button.grid        :column=>0, :row=>row.next, :sticky=>"ew", :columnspan=>2
    Tk::Tile::Separator.new(self){orient 'horizontal'}.grid :column=>0, :row=>row.next, :sticky=>'ew', :columnspan=>2, :pady=>'2'
    progress_bar.grid       :column=>0, :row=>row.next, :sticky=>"ew", :columnspan=>2
    Tk::Tile::Separator.new(self){orient 'horizontal'}.grid :column=>0, :row=>row.next, :sticky=>'ew', :columnspan=>2, :pady=>'2'
    buildup_ani_frame.grid  :column=>0, :row=>row.next, :sticky=>"ew", :columnspan=>2
    Tk::Tile::Separator.new(self){orient 'horizontal'}.grid :column=>0, :row=>row.next, :sticky=>'ew', :columnspan=>2, :pady=>'2'
    animation_controls.grid     :column=>0, :row=>row.next, :sticky=>'nsew',:columnspan=>3

    cols, rows = grid_size
    0.upto(cols-1).map{ |col| TkGrid.columnconfigure self, col, :weight=>1 } 
    0.upto(rows-1).map{ |row| TkGrid.rowconfigure    self, row, :weight=>1 }
  end
  display_frame = TkFrame.new self do
    borderwidth 3
    #minsize = [300,300]
    relief "raised"
    background 'blue'
    canvas = times_table.canvas
    canvas.pack :in=>self, :fill=>"both", :expand=>"1" 
  end
  controls_frame.grid :row=>0, :column=>0, :sticky=>'n'
  display_frame.grid  :row=>0, :column=>1, :sticky=>'nsew'
  TkGrid.rowconfigure    self, 0, :weight=>1, :minsize=>'10'
  TkGrid.columnconfigure self, 0, :weight=>0 
  TkGrid.columnconfigure self, 1, :weight=>1, :minsize=>'10'
  grid :column=>0, :row=> 0, :sticky=>"nsew"

  times_table.on
end
TkGrid.rowconfigure root, 0, :weight=>1
TkGrid.columnconfigure root, 0, :weight=>1
#root['geometry'] = '400x400+100+30'
root.bind("h"){ about_box }
root.bind("x"){ exit }

root['state'] = 'normal'
#root.iconify   # minimizes the window
#Tk.focus will return the widget that has the current focus
Tk.mainloop
