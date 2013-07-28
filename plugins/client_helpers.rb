# encoding: utf-8

require 'RMagick'

module Ruhoh::Resources::Pages
  class Client
  	Help_Image = [
    	{
      	"command" => "image <img_file> <title>",
      	"desc" => "Create a new post with image."
    	}
    ]

		def image
      filename, title = filename_and_title @args[3]
      begin
        bn = []
        (File.directory?(@args[2]) ? 
              Dir.entries(@args[2]).map {|d| File.join(@args[2], d) } : [@args[2]]).each { |f| 
          Ruhoh::Friend.say { blue "Processing #{f}..." }
          begin
            img = Magick::Image::read(f).first
            report_img_data img
            bn << scale_images(img, title)
          rescue
            Ruhoh::Friend.say { yellow "Found non-image file #{f}. Skipping..." }
          end
        }
        raise if bn.empty?
        create_template filename, title, bn
      rescue => e
        Ruhoh::Friend.say { 
          red "Image creation requires a valid image file."
          plain "  Please specify proper image file."
          red e.backtrace.join("\n")
          exit
        }
      end
		end

    private 
    def report_img_data img
      Ruhoh::Friend.say { 
        green "Image loaded successfully:"

        plain "   Format: #{img.format}"
        cyan  "   Geometry: #{img.columns}x#{img.rows}"
        cyan  "   Orientation: #{img.orientation}" if img.orientation
        plain "   Class: " + case img.class_type
                             when Magick::DirectClass
                                 "DirectClass"
                             when Magick::PseudoClass
                                 "PseudoClass"
                             end
        plain "   Depth: #{img.depth} bits-per-pixel"
        plain "   Colors: #{img.number_colors}"
        plain "   Filesize: #{img.filesize}"
        units = begin
          img.units == Magick::PixelsPerInchResolution ? "inch" : "centimeter"
        rescue 
          "inch"
        end
        cyan  "   Resolution: #{img.x_resolution.to_i}x#{img.y_resolution.to_i} pixels/#{units}"
        if img.properties.length > 0
            plain "   Properties:"
            img.properties { |name,value|
              if name =~ /date/i
                cyan  %Q|      #{name} = "#{value}"|
              elsif name =~ /^exif:PixelX/ && value != img.columns.to_s
                red   %Q|      #{name} = "#{value}"|
              elsif name =~ /^exif:PixelY/ && value != img.rows.to_s
                red   %Q|      #{name} = "#{value}"|
              elsif
                plain %Q|      #{name} = "#{value}"|
              end
            }
        end     
      }
    end

    def scale_images img, title
      case img.orientation 
      when Magick::RightTopOrientation
        img.rotate!(90)
      when Magick::BottomRightOrientation
        img.rotate!(180)
      when Magick::LeftBottomOrientation
        img.rotate!(-90)
      end

      now = (Time.now.to_f * 1000.0).to_i
      img_config = @ruhoh.config['images']
      result = nil

      # TODO Find out, how we can get this info from EXIF!!
      date = Date.parse(img.properties['exif:DateTime'].gsub(/:/, '/')) if img.properties['exif:DateTime']
      date ||= Date.parse(img.properties['date:modify']) if img.properties['date:modify']
      date ||= Date.parse(img.properties['date:create']) if img.properties['date:create']
      date ||= Date.parse(img.properties['xap:CreateDate']) if img.properties['xap:CreateDate']

      # write images
      scales = img_config['scales'] || [800,150]
      scales.each { |sz| 
        next if sz >= img.columns
        curr = img.resize_to_fit(sz)

        imgfilename = "#{now}-#{sz}.#{img.format.downcase}"
        result = imgfilename unless result
        currfile = File.join(@ruhoh.paths.base, "media", imgfilename)
        Ruhoh::Friend.say { 
          green "Writing file #{currfile} (#{sz}×#{img.rows*sz/img.columns})"
        }

        if img_config['watermark'] && img_config['watermark']['use'] && sz > (img_config['watermark']['min'] || 500)
          mark = Magick::Image.new(curr.rows, curr.columns) do
            self.background_color = 'transparent'
          end
          wm_text = img_config['watermark']['text'] ? 
                    img_config['watermark']['text'] : img_config['production_url']
          wm_text = "#{date} @ #{wm_text}" if img_config['watermark']['date']
          Magick::Draw.new.annotate(mark, 0, 0, 5, 2, wm_text) do
            self.gravity = Magick::SouthEastGravity
            self.fill 'rgba(60%, 60%, 60%, 0.40)'
            self.stroke = 'none'
            self.pointsize = 1 + 2 * Math.log(sz, 3).to_i
            self.font_family = 'Ubuntu'
            self.font_weight = Magick::NormalWeight
            self.font_style = Magick::NormalStyle
          end
          curr = curr.composite(mark.rotate(-90), Magick::SouthEastGravity, Magick::SubtractCompositeOp)
          Ruhoh::Friend.say { cyan  "        ⇒ with watermark “#{wm_text}”" }
        else
          Ruhoh::Friend.say { plain "        ⇒ without watermark" }
        end

        curr.write currfile
      }
      result
    end

    def create_template filename, title, basename
      FileUtils.mkdir_p File.dirname(filename)
      output =  (@collection.scaffold || '').
                 gsub('{{DATE}}', Time.now.strftime('%Y-%m-%d')).
                 gsub('{{TITLE}}', title)

# FIXME This is to be done thru templates
#      output += (@collection.scaffold(_image) || '').
#                 gsub('{{IMGFILE}}', "/media/#{basename}").
#                 gsub('{{IMGTITLE}}', title)

      basename.each { |bn| 
        output += "\n<figure>\n" + \
                  "\t<img src=\"{{urls.media}}/#{bn}\" alt=\"#{title}\" />\n" + \
                  "\t<figcaption><p>#{title}</p></figcaption>\n" + \
                  "</figure>\n"
      }

      File.open(filename, 'w:UTF-8') { |f| f.puts output }

      resource_name = @collection.resource_name
      Ruhoh::Friend.say { 
        green "New #{resource_name}:"
        cyan  "        ⇒ #{filename}"
      }
    end

  end
end