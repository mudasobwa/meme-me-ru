# encoding: utf-8

require 'RMagick'

module Magick
  class ImageList
    def self.debug_mode?
      true
    end
    def self.preview dir, width=120, cols=5, options={}
      options = {
        :shadow           => 'true',
        :shadow_color     => 'gray40',
        :background_color => 'black',
        :compose          => ChangeMaskCompositeOp,
        :border_color     => 'gray20',
        :border_width     => 1
      }.merge(options)
      imgs = ImageList.new
      imgnull = Image.new(width,width) { self.background_color = 'transparent' }
      imgnull2 = Image.new(width,width) { self.background_color = 'transparent' }
      (cols+1).times { imgs << imgnull.dup }
      imgs << imgnull2.dup
      Dir.glob("#{dir}/**") { |f|
        print '*' if debug_mode?
        Image::read(f).each { |i| 
          scale = (0.9 + 0.2*rand(1))*width/[i.columns, i.rows].max
          imgs << imgnull.dup if (imgs.size % (cols+2)).zero?
          imgs << i.auto_orient.thumbnail(scale).polaroid(rand(40)-20)
          imgs << imgnull2.dup if (imgs.size % (cols+2)) == cols+1
        } rescue puts "ERROR: #{$!}" if debug_mode?  # simply skipping non-image files
      }
      # Fill the rest
      (cols+1-(imgs.size % (cols+2))).times { imgs << imgnull.dup }
      (cols+3).times { imgs << imgnull2.dup }
      puts " => #{imgs.size}" if debug_mode?
      imgs.montage { 
        self.tile             = Magick::Geometry.new(cols+2) 
        self.geometry         = "-#{width/5}-#{width/4}"
        self.background_color = 'white'
        self.border_color     = 'lavender'
      }.trim(true).rotate(-5).border(1,1,'#DDD')
    end
  end
end