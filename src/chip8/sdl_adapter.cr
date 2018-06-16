require "sdl"

module Chip8
  class SDLAdapter
    WIDTH  = 1024
    HEIGHT =  512
    KEYMAP = [
      LibSDL::Keycode::X,
      LibSDL::Keycode::KEY_1,
      LibSDL::Keycode::KEY_2,
      LibSDL::Keycode::KEY_3,
      LibSDL::Keycode::Q,
      LibSDL::Keycode::W,
      LibSDL::Keycode::E,
      LibSDL::Keycode::A,
      LibSDL::Keycode::S,
      LibSDL::Keycode::D,
      LibSDL::Keycode::Z,
      LibSDL::Keycode::C,
      LibSDL::Keycode::KEY_4,
      LibSDL::Keycode::R,
      LibSDL::Keycode::F,
      LibSDL::Keycode::V,
    ]

    def initialize(console : Chip8::Console)
      SDL.init(SDL::Init::VIDEO)

      @console = console
      @window = SDL::Window.new("Chip-8", WIDTH, HEIGHT)

      @renderer = SDL::Renderer.new(@window)
      ret = LibSDL.render_set_logical_size(@renderer, w: WIDTH, h: HEIGHT)
      raise "LibSDL error" unless ret == 0

      @pixels = Array(UInt32).new(Chip8::Console::DISPLAY_SIZE, 0_u32)

      # https://github.com/snowkit/linc_sdl/blob/master/sdl/SDL.hx
      texture = LibSDL.create_texture(
        renderer: @renderer,
        format: 0x16362004,
        access: LibSDL::TextureAccess::STREAMING,
        w: Chip8::Console::WIDTH,
        h: Chip8::Console::HEIGHT,
      )
      raise "LibSDL error" unless texture

      @texture = SDL::Texture.new texture

      at_exit { SDL.quit }
    end

    def draw
      @renderer.clear

      @console.display.each_with_index do |byte, i|
        @pixels[i] = ((0x00FFFFFF * byte) | 0xFF000000).to_u32
      end

      ret = LibSDL.update_texture(
        texture: @texture,
        pixels: @pixels,
        pitch: 64 * sizeof(UInt32),   # the number of bytes in a row of pixel data, including padding between lines
        rect: Pointer(SDL::Rect).null # redraw everything
      )
      raise "LibSDL error" unless ret == 0

      @renderer.copy(@texture)
      @renderer.present
      @console.drawn

      sleep ENV["DELAY"]? ? ENV["DELAY"].to_f : 0.015
    end

    def handle_keyboard : Bool
      event = SDL::Event.poll

      case event
      when SDL::Event::Quit
        return false
      when SDL::Event::Keyboard
        if event.mod.lctrl? && event.sym.q?
          return false
        end

        (0...KEYMAP.size).each do |i|
          @console.keypress(i, event.keydown? ? 1.to_u16 : 0.to_u16) if event.sym == KEYMAP[i]
        end
      end

      true
    end
  end
end
