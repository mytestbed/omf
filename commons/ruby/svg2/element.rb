
#==============================================================================#
# svg/element.rb
# $Id: element.rb,v 1.14 2003/02/06 14:59:43 yuya Exp $
#==============================================================================#

#==============================================================================#
# SVG Module
module SVG2

  class Base

    Attributes = [
      'stroke',                      #
      'stroke-dasharray',            #
      'stroke-dashoffset',           #
      'stroke-linecap',              # round | butt | square | inherit
      'stroke-linejoin',             # round | bevel | miter | inherit
      'stroke-miterlimit',           #
      'stroke-opacity',              #
      'stroke-width',                #
      'fill',                        #
      'fill-opacity',                #
      'fill-rule',                   # evenodd | nonzero | inherit
      'alignment-baseline',          # auto | baseline | before-edge | text-before-edge | middle | after-edge | text-after-edge | ideographic | alphabetic | hanging | mathematical | inherit
      'baseline-shift',              # baseline | sub | super | <percentage> | <length> | inherit
      'direction',                   # ltr | rtl | inherit
      'dominant-baseline',           # auto | autosense-script | no-change | reset | ideographic | lower | hanging | mathematical | inherit
      'font',                        #
      'font-family',                 #
      'font-size',                   #
      'font-size-adjust',            # [0-9]+ | none | inherit
      'font-stretch',                # normal | wider | narrower | ultra-condensed | extra-condensed | condensed | semi-condensed | semi-expanded | expanded | extra-expanded | ultra-expanded | inherit
      'font-style',                  # normal | italic | oblique | inherit
      'font-variant',                # normal | small-caps | inherit
      'font-weight',                 # normal | bold | bolder | lighter | 100 | 200 | 300 | 400 | 500 | 600 | 700 | 800 | 900 | inherit
      'glyph-orientation-hoizontal', # <angle> | inherit
      'glyph-orientation-vertical',  # auto | <angle> | inherit
      'kerning',                     # auto | <length> | inherit
      'letter-spacing',              # normal | <length> | inherit
      'text-anchor',                 # start | middle | end | inherit
      'text-decoration',             # none | underline | overline | line-through | blink | inherit
      'text-rendering',              # auto | optimizeSpeed | optimizeLegibility | geometricPrecision | inherit
      'unicode-bidi',                # normal | embed | bidi-override | inherit
      'word-spacing',                # normal | length | inherit
      'writing-mode',                # lr-tb | rl-tb | tb-rl | lr | rl  | tb | inherit
      'clip',                        # auto | rect(...) | inherit
      'clip-path',                   # <uri> | none | inherit
      'clip-rule',                   # evenodd | nonzero | inherit
      'color',                       #
      'color-interpolation',         # auto | sRGB | linearRGB | inherit
      'color-rendering',             # auto | optimizeSpeed | optimizeQuality | inherit
      'cursor',                      # [ [<uri> ,]* [ auto | crosshair | default | pointer | move | e-resize | ne-resize | nw-resize | n-resize | se-resize | sw-resize | s-resize | w-resize| text | wait | help ] ] | inherit
      'display',                     # inline | none | inherit
      'enable-background',           # accumulate | new [ ( <x> <y> <width> <height> ) ] | inherit
      'filter',                      # <uri> | none | uri
      'image-rendering',             # auto | optimizeSpeed | optimizeQuality
      'marker',                      #
      'marker-end',                  # none | <uri>
      'marker-mid',                  #
      'marker-start',                #
      'mask',                        #
      'opacity',                     #
      'overflow',                    # visible | hidden | scroll  | auto | inherit
      'pointer-events',              # visiblePainted | visibleFill | visibleStroke | visible | painted | fill | stroke | all | none | inherit
      'rendering-intent',            # auto | perceptual | relative-colorimetric | saturation | absolute-colorimetric | inherit
      'shape-rendering',             # auto | optimizeSpeed | crispEdges|geometricPrecision | inherit
      'visibility',                  # visible | hidden | collapse | inherit
    ]

    @@class2props = {}

    @@attr2attr = {}
    Attributes.each { |attr|
      name = attr.gsub(/-/, '_')
      class_eval(<<-EOS)
        def #{name}
          return @attributes['#{attr}']
        end
        def #{name}=(value)
          @attributes['#{attr}'] = value
        end
      EOS
      @@attr2attr[name.to_sym] = attr
    }

    def self.property(*args)
      args.each {|name|
        class_eval(<<-EOS)
          def #{name}
            return @props[:#{name}]
          end
          def #{name}=(value)
            @props[:#{name}] = value
          end
        EOS
      }
      if ((props = @@class2props[self]) == nil)
        sprops = @@class2props[self.superclass]
        props = sprops.nil? ? {} : sprops.clone
        @@class2props[self] = props
      end
      args.each {|name|
        props[name] = "@#{name}".to_sym
      }
    end

    def initialize(props, &block)
      @props ||= {}

      if (props.size > 0)
        init(props)
      end
      if block_given?
        #instance_eval(&block)
        block.call(self)
      end
    end

    def init(props = {})
      propList = @@class2props[self.clasz]
      if propList.nil?
        # didn't have an extra attribute
        cl = self.clasz.superclass
        while (cl != nil && (propList = @@class2props[cl]) == nil)
          cl = cl.superclass
        end
        if propList.nil?
          raise "No attributes found for #{self.clasz} (#{@@class2props.keys.join(' ')})"
        end
        @@class2props[self.clasz] = propList
      end

      props.each {|name, value|
        if propList.has_key?(name)
          @props[name] = value
        else
          if ((key = @@attr2attr[name]) != nil)
            @attributes[key] = value
          else
            raise "Unknown property or attribute '#{name}'"
          end
        end
      }
    end

    alias_method :clasz, :class


  end # Base

  #============================================================================#
  # Picture Class
  class Picture < Base

    property :width, :height, :x, :y, :view_box, :title, :desc, :version

    include ArrayMixin
    include GroupMixin

    def initialize(props, &block)
      @props ||= {}
      @props[:width]    = 100
      @props[:height]   = 100
      @props[:x]        = nil
      @props[:y]        = nil
      @props[:view_box] = nil
      @props[:title]    = nil
      @props[:desc]     = nil
      @props[:version]  = '1.0'

      @elements = []
      @styles   = []
      @scripts  = []

      super(props, &block)
    end

    attr_reader   :elements, :styles, :scripts

    def array
      return @elements
    end
    private :array

    def define_style(class_name, style)
      @styles << DefineStyle.new(class_name, style)
    end


    def to_s
      text  = %|<?xml version="1.0" standalone="no"?>\n|
      text << %|<svg|
      text << %| xmlns="http://www.w3.org/2000/svg"|
      text << %| xmlns:xlink="http://www.w3.org/1999/xlink"|
      text << %| version="#{@props[:version]}"| if @props[:version]
      text << %| width="#{@props[:width]}" height="#{@props[:height]}"|
      text << %| viewBox="#{@props[:view_box]}"| if @props[:view_box]
      text << %|>\n|

      @scripts.each { |script|
        text << script.to_s
      }

      unless @styles.empty?
        text << %|<defs>\n|
        text << %|<style type="text/css"><![CDATA[\n|
        text << @styles.collect { |define| define.to_s + "\n" }.join
        text << %|]]></style>\n|
        text << %|</defs>\n|
      end

      text << %|<title>#{@title}</title>\n| if @title
      text << %|<desc>#{@desc}</desc>\n|    if @desc
      text << @elements.collect { |element| element.to_s + "\n" }.join
      text << %|</svg>\n|
      return text
    end

    def svg
      return self.to_s
    end

    def svgz
      require 'zlib'
      return Deflate.deflate(self.to_s, Deflate::BEST_COMPRESSION)
    end

    def mime_type
      return 'image/svg+xml'
    end

  end # Picture

  #============================================================================#
  # ElementBase Class
  class ElementBase < Base



#    @props = {}

    def initialize(props = {}, &block)
      @attributes = {}
      @props ||= {}
      @props[:id]        = nil
      @props[:style]     = nil
      @props[:class]     = nil
      @props[:transform] = nil
      @props[:attr]      = nil
      super(props, &block)
    end


    property :id, :class, :transform

    def to_s
      style = nil
      unless @attributes.empty?
        style = @attributes.select { |key, value|
          !value.nil?
        }.sort { |(a_key, a_value), (b_key, b_value)|
          a_key <=> b_key
        }.collect { |key, value|
          "#{key}: #{value};"
        }.join(' ')
      end
      text = ''
      text << %| id="#{@props[:id]}"|               if @props[:id]
      text << %| style="#{style}"|                  if style
      text << %| class="#{@props[:class]}"|         if @props[:class]
      text << %| transform="#{@props[:transform]}"| if @props[:transform]
      text << %| #{@props[:attr]}|                  if @props[:attr]
      return text
    end

  end # ElementBase

  #============================================================================#
  # Group Class
  class Group < ElementBase

    include ArrayMixin
    include GroupMixin

    # style
    def initialize(props = {}, &block)
      @props ||= {}
      @props[:elements] = []
      super(props, &block)
    end

    attr_reader :elements

    def array
      return @props[:elements]
    end
    private :array

    def to_s
     text = %|<g|
     text << super()
     text << %|>\n|
     text << @props[:elements].collect { |element| element.to_s + "\n" }.join
     text << %|</g>\n|
    end

  end # Group

  #============================================================================#
  # Anchor Class
  class Anchor < ElementBase

    include ArrayMixin

    def initialize(uri)
      super()
      @props[:uri]      = uri
      @props[:elements] = []
    end

    property :uri
    attr_reader   :elements

    def array
      return @props[:elements]
    end
    private :array

    def to_s
     text = %|<a|
     text << super()
     text << %| xlink:href="#{@props[:uri]}">\n|
     text << @props[:elements].collect { |element| element.to_s + "\n" }.join
     text << %|</a>\n|
    end

  end # Anchor

  #============================================================================#
  # Use Class
  class Use < ElementBase

    def initialize(uri)
      super()
      @props[:uri]      = uri
    end

    property :uri

    def to_s
     text = %|<use|
     text << super()
     text << %| xlink:href="#{@props[:uri]}"/>\n|
    end

  end # Use

  #============================================================================#
  # Rect Class
  class Rect < ElementBase

    # x = 0, y = 0, width = 0, height = 0, rx = nil, ry = nil
    def initialize(props = {}, &block)
      @props ||= {}
      @props[:x]      = nil
      @props[:y]      = nil
      @props[:width]  = 0
      @props[:height] = 0
      @props[:rx]     = nil
      @props[:ry]     = nil
      super(props, &block)
    end

    property :width, :height, :x, :y, :rx, :ry

    def to_s
      text = %|<rect width="#{@props[:width]}" height="#{@props[:height]}"|
      text << %| x="#{@props[:x]}"|   if @props[:x]
      text << %| y="#{@props[:y]}"|   if @props[:y]
      text << %| rx="#{@props[:rx]}"| if @props[:rx]
      text << %| ry="#{@props[:ry]}"| if @props[:ry]
      text << super()
      text << %| />|
      return text
    end

  end # Rect

  #============================================================================#
  # Circle Class
  class Circle < ElementBase

    #cx = 0, cy = 0, r = 0
    def initialize(props = {}, &block)
      @props ||= {}
      @props[:cx] = @props[:cy] = @props[:r] = 0
      super(props, &block)
    end

    property :cx, :cy, :r

    def to_s
      text = %|<circle cx="#{@props[:cx]}" cy="#{@props[:cy]}" r="#{@props[:r]}"|
      text << super()
      text << %| />|
      return text
    end

  end # Circle

  #============================================================================#
  # Ellipse Class
  class Ellipse < ElementBase

    # cx, cy, rx, ry
    def initialize(props = {}, &block)
      @props ||= {}
      @props[:cx] = @props[:cy] = @props[:rx] = @props[:ry] = 0
      super(props, &block)
    end

    property :cx, :cy, :rx, :ry

    def to_s
      text = %|<ellipse cx="#{@props[:cx]}" cy="#{@props[:cy]}" rx="#{@props[:rx]}" ry="#{@props[:ry]}"|
      text << super()
      text << %| />|
      return text
    end

  end # Ellipse

  #============================================================================#
  # Line Class
  class Line < ElementBase

    # x1, y1, x2, y2
    def initialize(props = {}, &block)
      @props ||= {}
      @props[:x1] = @props[:y1] = @props[:x2] = @props[:y2] = 0
      super(props, &block)
      unless (from = @props[:from])
        @props[:x1] = from[0]
        @props[:y1] = from[1]
      end
    end

    property :x1, :y1, :x2, :y2
    property :from, :to

    def from=(p)
      if (! (p.instance_of?(Array) && p.size == 2))
        raise "Expected x,y array"
      end
      @props[:x1] = p[0]
      @props[:y1] = p[1]
    end

    def from()
      [@props[:x1], @props[:y1]]
    end

    def to=(p)
      if (! (p.instance_of?(Array) && p.size == 2))
        raise "Expected x,y array"
      end
      @props[:x2] = p[0]
      @props[:y2] = p[1]
    end

    def to()
      [@props[:x2], @props[:y2]]
    end

    def to_s
      text = %|<line x1="#{@props[:x1]}" y1="#{@props[:y1]}" x2="#{@props[:x2]}" y2="#{@props[:y2]}"|
      text << super()
      text << %| />|
      return text
    end

  end # Line

  #============================================================================#
  # AbstractPoly Class
  class AbstractPoly < ElementBase

    # points
    def initialize(props = {}, &block)
      @props ||= {}
      @props[:points] = []
      super(props, &block)
    end

    property :points

    def point(x, y)
      @props[:points] << "#{x},#{y}"
    end

    # Add array of points
    def points(*pa)
      a = @props[:points]
      pa.each { |p|
        a << "#{p[0]},#{p[1]}"
      }
    end
  end

  #============================================================================#
  # Polyline Class
  class Polyline < AbstractPoly

    def to_s
      text = %|<polyline points="#{@props[:points].join(' ')}"|
      text << super()
      text << %| />|
      return text
    end

  end # Polyline

  #============================================================================#
  # Polygon Class
  class Polygon < AbstractPoly

    def to_s
      text = %|<polygon points="#{@props[:points].join(' ')}"|
      text << super()
      text << %| />|
      return text
    end

  end # Polygon

  #============================================================================#
  # Image Class
  class Image < ElementBase

    # x, y, width, height, href
    def initialize(props = {}, &block)
      @props ||= {}
      @props[:x] = @props[:y] = nil
      @props[:width] = @props[:height] = 0
      @props[:href] = nil
      super(props, &block)
    end

    property :x, :y, :width, :height, :href

    def to_s
      text = %|<image|
      text << %| x="#{@props[:x]}"| if @props[:x]
      text << %| y="#{@props[:y]}"| if @props[:y]
      text << %| width="#{@props[:width]}"|
      text << %| height="#{@props[:height]}"|
      text << %| xlink:href="#{@props[:href]}"|
      text << super()
      text << %| />|
      return text
    end

  end # Image

  #============================================================================#
  # Path Class
  class Path < ElementBase

    # path, length
    def initialize(props = {}, &block)
      @props ||= {}
      @props[:path]   = []
      @props[:length] = nil
      super(props, &block)
    end

    property :path, :length

    def to_s
      text = %|<path d="#{@props[:path].join(' ')}"|
      text = %| length="#{@props[:length]}"| if @props[:length]
      text << super()
      text << %| />|
      return text
    end

  end # Path

  #============================================================================#
  # Text Class
  class Text < ElementBase

    # x, y, text
    def initialize(props = {}, &block)
      @props ||= {}
      @props[:x] = @props[:y] = @props[:length] = @props[:length_adjust] = nil
      @props[:text] = ""
      super(props, &block)
    end

    property :x, :y, :text, :length, :length_adjust

    def to_s
      svg =  %|<text|
      svg << %| x="#{@props[:x]}"|                        if @props[:x]
      svg << %| y="#{@props[:y]}"|                        if @props[:y]
      svg << %| textLength="#{@props[:length]}"|          if @props[:length]
      svg << %| lengthAdjust="#{@props[:length_adjust]}"| if @props[:length_adjust]
      svg << super()
      svg << %|>|
      svg << @props[:text]
      svg << %|</text>|
      return svg
    end

  end # Text

  #============================================================================#
  # Verbatim Class
  class Verbatim < Base

    def initialize(xml)
      @props ||= {}
      @props[:xml] = xml
    end

    property :xml

    def to_s
      return @props[:xml]
    end

  end # Verbatim

end # SVG

#==============================================================================#
#==============================================================================#
