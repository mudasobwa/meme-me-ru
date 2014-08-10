# encoding: utf-8

require 'digest/md5'
require 'RMagick'
require 'rmagick/screwdrivers'
require 'qipowl/core/monkeypatches'

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
      if File.directory?(@args[2])
        # Update summary when new image is to be added to existing folder
        sum_file = "#{File.basename(@args[2]).gsub(/\W/,'-')}.jpg"
        Magick::Screwdrivers.collage(@args[2]).write File.join('/home/am/Projects/Sites/meme-me-ru', "media", sum_file)
        create_template(filename, title, Dir.entries(@args[2]).map { |d| File.join(@args[2], d) }, sum_file)
      else
        update_template(filename, title, @args[2])
      end
    end

  private
    def debug_mode?
      true
    end

    def filename_and_title(s=nil,opts={})
      begin
        file = s || "untitled"
        ext = File.extname(file).to_s
        ext  = ext.empty? ? @collection.config["ext"] : ext

        # filepath vs title
        name = file.include?('/') ?
               File.join(File.dirname(file), File.basename(file, ext).gsub(/\s+/, '-').to_filename) :
               file.to_filename

        name = "#{name}-#{@iterator}" unless @iterator.zero?
        filename = opts[:draft] ?
          File.join(@ruhoh.paths.base, @collection.resource_name, "drafts", "#{name}#{ext}") :
          File.join('/home/am/Projects/Sites/meme-me-ru', @collection.resource_name, "#{name}#{ext}")
#          File.join(@ruhoh.paths.base, @collection.resource_name, "#{name}#{ext}")
        @iterator += 1
      end while File.exist?(filename)
      [filename, file.gsub(/.*?\//, '')]
    end

    def img_md5 img
      Digest::MD5.hexdigest(img.to_blob)
    end

    def fig anchor, title, file
      # ![Test image]({{urls.media}}/1375648795555-600.jpeg "Test title")
      "\n<a id='#{anchor}'></a>![#{title}]({{urls.media}}/#{file} '#{title}')\n"
    end

    def preview title, file
      "\n<div class='preview'><img src='{{urls.media}}/#{file}' alt='#{title}'></div>\n"
    end

    def update_template filename, title, img
      if File.exist?(filename)
        File.write filename, 
                   fig(File.basename(name, '.*'), title, (scale_images([img])).first),
                   File.size(filename),
                   mode: 'a'
        res = @collection.resource_name
        Ruhoh::Friend.say { green "Updated #{res} ⇒ “#{filename}”" }
      else 
        create_template filename, title, [img]
      end
    end

    def create_template filename, title, imgs, summary
      FileUtils.mkdir_p File.dirname(filename)
      output =  (@collection.scaffold || '').
                 gsub('{{DATE}}', Time.now.strftime('%Y-%m-%d')).
                 gsub('{{TITLE}}', title)

      output += preview(title, summary) unless summary.nil?

      scale_images(imgs).each { |img|
        output += (fig(File.basename(img, '.*'), title, img) rescue '')
      }
      File.open(filename, 'w:UTF-8') { |f| f.puts output }
      res = @collection.resource_name
      Ruhoh::Friend.say { green "New #{res} ⇒ “#{filename}”" }
    end

    def scale_images imgs
      begin
        img_names = []
        imgs.each { |f| 
          Ruhoh::Friend.say { blue "Scaling #{f}..." }
          begin
            img = Magick::Image::read(f).first
            report_img_data img
            img_names << scale_image(img)
          rescue
            Ruhoh::Friend.say {
              yellow "Found non-image file #{f}. Skipping..." 
              red $!
            }
          end
        }
        raise if img_names.empty?
        img_names
      rescue => e
        Ruhoh::Friend.say { 
          red "Image creation requires a valid image file."
          plain "  Please specify proper image file."
          red e.backtrace.join("\n")
          exit
        }
      end
    end

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
        # 36867 0x9003  DateTimeOriginal  The date and time when the original image data was generated.
        cyan  "   DateTime: #{img.get_exif_by_number(36867)[36867]}"
        if false && img.properties.length > 0
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

    def scale_image img
      case img.orientation 
      when Magick::RightTopOrientation
        img.rotate!(90)
      when Magick::BottomRightOrientation
        img.rotate!(180)
      when Magick::LeftBottomOrientation
        img.rotate!(-90)
      end

      imgname = img_md5(img)
      imgformat = case img.format.downcase
                  when 'png' then 'png'
                  when 'gif' then 'gif'
                  else 'jpg'
                  end
      img_config = @ruhoh.config['images']
      result = nil

      date = img.get_exif_by_number(36867)[36867]
      date = Date.parse(date.gsub(/:/, '/')) if date
      date ||= Date.parse(img.properties['exif:DateTime'].gsub(/:/, '/')) if img.properties['exif:DateTime']
      date ||= Date.parse(img.properties['date:modify']) if img.properties['date:modify']
      date ||= Date.parse(img.properties['date:create']) if img.properties['date:create']
      date ||= Date.parse(img.properties['xap:CreateDate']) if img.properties['xap:CreateDate']

      # write images
      scales = img_config['scales'] || [800,150]
      scales.each { |sz| 
        next if sz >= img.columns
        curr = img.resize_to_fit(sz)

        imgfilename = "#{imgname}-#{sz}.#{imgformat}"
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

        curr.write(currfile) { self.quality = 90 }
      }
      result
    end

  end
end
