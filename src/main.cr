# Note: this code is terrible and you should not use it
# Written from curiosity regarding how much it would take
# To write an emulator / interpreter with Crysta and how
# Type inference works in practice at this stage

require "./chip8/console"
require "./chip8/sdl_adapter"

console = Chip8::Console.new
display_adapter = Chip8::SDLAdapter.new(console)
console.load(ARGV[0])

loop do
  console.cycle
  break unless display_adapter.handle_keyboard

  display_adapter.draw if console.draw?
end
