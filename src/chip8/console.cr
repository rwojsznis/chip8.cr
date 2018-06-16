module Chip8
  class Console
    WIDTH        = 64_u16
    HEIGHT       = 32_u16
    DISPLAY_SIZE = WIDTH * HEIGHT
    SPRITE_WIDTH =     8_u8
    MEM_SIZE     = 4096_u16
    REGISTERS    =    16_u8
    STACK_SIZE   =    16_u8
    KEYS         =    16_u8
    FONTSET      = [
      0xF0, 0x90, 0x90, 0x90, 0xF0, # 0
      0x20, 0x60, 0x20, 0x20, 0x70, # 1
      0xF0, 0x10, 0xF0, 0x80, 0xF0, # 2
      0xF0, 0x10, 0xF0, 0x10, 0xF0, # 3
      0x90, 0x90, 0xF0, 0x10, 0x10, # 4
      0xF0, 0x80, 0xF0, 0x10, 0xF0, # 5
      0xF0, 0x80, 0xF0, 0x90, 0xF0, # 6
      0xF0, 0x10, 0x20, 0x40, 0x40, # 7
      0xF0, 0x90, 0xF0, 0x90, 0xF0, # 8
      0xF0, 0x90, 0xF0, 0x10, 0xF0, # 9
      0xF0, 0x90, 0xF0, 0x90, 0x90, # A
      0xE0, 0x90, 0xE0, 0x90, 0xE0, # B
      0xF0, 0x80, 0x80, 0x80, 0xF0, # C
      0xE0, 0x90, 0x90, 0x90, 0xE0, # D
      0xF0, 0x80, 0xF0, 0x80, 0xF0, # E
      0xF0, 0x80, 0xF0, 0x80, 0x80, # F
    ].map(&.to_u8)

    getter :display

    def initialize
      @mem = Array(UInt8).new(MEM_SIZE, 0_u8)
      @display = Array(UInt8).new(DISPLAY_SIZE, 0_u8)
      @v = Array(UInt8).new(REGISTERS, 0_u8)

      @stack = Array(UInt16).new(STACK_SIZE, 0_u16)
      @keypad = Array(UInt16).new(KEYS, 0_u16)

      @pc = 0x200_u16
      @opcode = 0_u16
      @i = 0_u16
      @sp = 0_u16

      @delay_timer = 0_u8
      @sound_timer = 0_u8
      @draw_flag = false

      FONTSET.each_with_index do |font, index|
        @mem[index] = font
      end
    end

    def draw?
      !!@draw_flag
    end

    def drawn
      @draw_flag = false
    end

    def load(file)
      rom = File.read(ARGV[0])
      rom.each_byte.each_with_index do |byte, index|
        @mem[index + 0x200] = byte
      end
    end

    def cycle
      # Note: cast it to u16 so we can shift it left (otherwise we will still have 8 bytes)
      opcode = @mem[@pc].to_u16 << 8 | @mem[@pc + 1]

      instruction(opcode)

      @delay_timer -= 1_u8 if @delay_timer > 0_u8

      if @sound_timer > 0_u8
        # make_a_beep if sound_timer == 1
        @sound_timer -= 1_u8
      end
    end

    def keypress(index, flag)
      @keypad[index] = flag
    end

    private def instruction(opcode)
      _x = (opcode & 0x0F00) >> 8
      _y = (opcode & 0x00F0) >> 4

      @pc += 2

      case opcode & 0xF000
      when 0x0000
        case opcode
        when 0x00E0
          (0...2048).each do |i|
            @display[i] = 0_u8
          end
          @draw_flag = true
        when 0x00EE
          @sp -= 1
          @pc = @stack[@sp]
        else
          raise "unknown code"
        end
      when 0x1000
        @pc = opcode & 0xFFF
      when 0x2000
        @stack[@sp] = @pc
        @sp += 1
        @pc = opcode & 0xFFF
      when 0x3000
        @pc += 2 if @v[_x] == opcode & 0xFF
      when 0x4000
        @pc += 2 if @v[_x] != opcode & 0xFF
      when 0x5000
        @pc += 2 if @v[_x] == @v[_y]
      when 0x6000
        @v[_x] = (opcode & 0xFF).to_u8
      when 0x7000
        @v[_x] += opcode & 0xFF
      when 0x8000
        case (opcode & 0x000F)
        when 0x0000
          @v[_x] = @v[_y]
        when 0x0001
          @v[_x] |= @v[_y]
        when 0x0002
          @v[_x] &= @v[_y]
        when 0x0003
          @v[_x] ^= @v[_y]
        when 0x0004
          @v[_x] += @v[_y]
          @v[0xF] = @v[_y] > 0xFF - @v[_x] ? 1_u8 : 0_u8
        when 0x0005
          @v[0xF] = @v[_y] > @v[_x] ? 0_u8 : 1_u8
          @v[_x] -= @v[_y]
        when 0x0006
          @v[0xF] = @v[_x] & 0x1
          @v[_x] >>= 1
        when 0x0007
          @v[0xF] = @v[_x] > @v[_y] ? 0_u8 : 1_u8
          @v[_x] = @v[_y] - @v[_x]
        when 0x000E
          @v[0xF] = @v[_x] >> 7
          @v[_x] <<= 1
        else
          raise "unknown code"
        end
      when 0x9000
        @pc += 2 if @v[_x] != @v[_y]
      when 0xA000
        @i = opcode & 0xFFF
      when 0xB000
        @pc = (opcode & 0xFFF) + @v[0]
      when 0xC000
        @v[_x] = ((rand * (0xFF + 1)).to_u8 & (opcode & 0xFF))
      when 0xD000
        height = opcode & 0xF

        registerX = @v[_x]
        registerY = @v[_y]

        @v[0xF] = 0_u8
        loc = 0_u16

        (0...height).each do |yline|
          pixel = @mem[@i + yline]

          (0...SPRITE_WIDTH).each do |xline|
            if (pixel & (0x80 >> xline)) != 0_u8
              # Something goes very wrong here with auto-casting :(
              # Took forever to track down
              loc = (registerX.to_u16 + xline.to_u16 + ((registerY.to_u16 + yline.to_u16) * WIDTH))

              loc -= DISPLAY_SIZE if loc > DISPLAY_SIZE
              @v[0xF] = 1_u8 if @display[loc] == 1
              @display[loc] ^= 1_u8
            end
          end
        end

        @draw_flag = true
      when 0xE000
        case (opcode & 0x00FF)
        when 0x009E
          @pc += 2 if @keypad[@v[_x]] != 0
        when 0x00A1
          @pc += 2 if @keypad[@v[_x]] == 0
        else
          raise "unknown code"
        end
      when 0xF000
        case (opcode & 0x00FF)
        when 0x0007
          @v[_x] = @delay_timer
        when 0x000A
          key_pressed = false

          @keypad.each_with_index do |key, i|
            if key != 0
              @v[_x] = i.to_u8
              key_pressed = true
            end
          end

          if !key_pressed
            @pc -= 2
            return
          end
        when 0x0015
          @delay_timer = @v[_x]
        when 0x0018
          @sound_timer = @v[_x]
        when 0x001E
          @v[0xF] = @i + @v[_x] > 0xFFF ? 1_u8 : 0_u8
          @i += @v[_x]
        when 0x0029
          @i = (@v[_x] * 0x5).to_u16
        when 0x0033
          @mem[@i] = @v[_x] / 100
          @mem[@i + 1] = (@v[_x] / 10) % 10
          @mem[@i + 2] = (@v[_x] % 100) % 10
        when 0x0055
          (0.._x).each { |i| @mem[@i + i] = @v[i] }
          @i += _x + 1
        when 0x0065
          (0.._x).each { |i| @v[i] = @mem[@i + i] }
          @i += _x + 1
        else
          raise "error"
        end
      else
        raise "error"
      end
    end
  end
end
