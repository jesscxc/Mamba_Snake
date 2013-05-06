#!/usr/bin/env ruby

# 2013-05
# Jesse Cummins
# https://github.com/jessc
# with advice from Ryan Metzler

=begin
# Bug List:

- Just keep throwing yourself at the problem!
- when game starts, if a different direction that :right is chosen,
    snake stretches weirdly (press up-right quickly)
    - as if the head is not at the furthest right but is in the middle
        of the snake
- if direction keys are pressed rapidly the snake can run on top
    of itself and instantly dies
- kind of has a glitchy feel where the snake "jumps" ahead,
    right before it catches the rabbit
- rabbit may still be able to respawn on the head of the snake?
- snake doesn't immediately start moving at beginning of game
    - I think it's because it's taking two steps to replace the white rabbit
        with the black snake
    - it looks like the head is at the end of the snake, rather than the start

# TODO:
- add timer
- add instructions at top of screen
- allow for multiple rabbits
- add highscore
- multiplayer game
- play against a snake AI
- rabbits can breed when near each other, grow old and die
- could go up trees to go to a new level
- snake could move diagonally
- rabbits could exhibit swarm behavior
- speed up snake with key presses or as it gets longer


=end

require 'gosu'
require 'yaml'

class Map
  attr_reader :width, :height

  def initialize(width, height)
    @map = Hash.new(:empty)
    @width = width
    @height = height

    (0...@height).each do |y|
      (0...@width).each do |x|
        @map[[x, y]] = :border if is_border(x, y)
      end
    end
  end

  def is_border(x, y)
    x == 0 || x == @width - 1 || y == 0 || y == @height - 1
  end

  def display
    (0...@height).each do |y|
      (0...@width).each do |x|
        print @map[[x, y]].to_s[0]
      end
      p ''
    end
  end

  def [](x, y)
    @map[[x, y]]
  end

  def []=(x, y, val)
    @map[[x, y]] = val
  end
end

class Rabbit
  attr_reader :color
  attr_accessor :pos, :distance

  DIRECTION = {
  up:    [0, -1],
  down:  [0, 1],
  left:  [-1, 0],
  right: [1, 0]}

  def initialize(x, y)
    @color = Gosu::Color::WHITE
    @dir = :right
    @default = 5
    @distance = @default
    @pos = [x, y]
  end

  def new_direction
    @dir = [:left, :right, :up, :down].sample
  end

  def next_hop(x, y)
    next_pos = [x, y]
    if @distance >= 1
      next_pos[0] += DIRECTION[@dir][0]
      next_pos[1] += DIRECTION[@dir][1]
    else
      @distance = @default
      new_direction
    end
    next_pos
  end
end


class Mamba
  attr_reader :color, :head, :body, :dir

  DIRECTION = {
  up:    [0, -1],
  down:  [0, 1],
  left:  [-1, 0],
  right: [1, 0]}

  def initialize(map_width, map_height)

    @color = Gosu::Color::BLACK
    @dir = :right
    @grow_length = 5
    @start_size = 5

    @body = []
    (0..@start_size).each do |n|
      @body << [(map_width / 2) - n, (map_height / 2)]
    end
    @head = @body.pop
  end

  def update
    @head[0] += DIRECTION[@dir][0]
    @head[1] += DIRECTION[@dir][1]

    @body.unshift [@head[0], @head[1]]
    @body.pop
  end

  def grow
    @grow_length.times { @body << @body[-1] }
  end

  def direction(id)
    @dir = case id
                 when Gosu::KbRight then @dir == :left  ? @dir : :right
                 when Gosu::KbUp    then @dir == :down  ? @dir : :up
                 when Gosu::KbLeft  then @dir == :right ? @dir : :left
                 when Gosu::KbDown  then @dir == :up    ? @dir : :down
                 else @dir
                 end
  end
end


class MambaSnakeGame < Gosu::Window
  module Z
    Border, Background, Map, Text, Snake, Rabbit = *1..100
  end

  settings = YAML.load_file 'config.yaml'

  WINDOW_WIDTH = settings['window_width']
  WINDOW_HEIGHT = settings['window_height']
  TILE_WIDTH = 20
  MAP_WIDTH = WINDOW_WIDTH / TILE_WIDTH
  MAP_HEIGHT = WINDOW_HEIGHT / TILE_WIDTH

  TITLE = 'Hungry Mamba!'
  TOP_COLOR = Gosu::Color::GREEN
  BOTTOM_COLOR = Gosu::Color::GREEN
  TEXT_COLOR = Gosu::Color::BLACK
  BORDER_COLOR = Gosu::Color::RED

  @paused = false

  def initialize
    super(WINDOW_WIDTH, WINDOW_HEIGHT, false, 100)
    @font = Gosu::Font.new(self, Gosu.default_font_name, 50)
    self.caption = TITLE
    new_game
  end

  def new_game
    @map = Map.new(MAP_WIDTH, MAP_HEIGHT)
    @snake = Mamba.new(MAP_WIDTH, MAP_HEIGHT)
    update_snake
    new_rabbit
  end

  def new_rabbit
    x, y = rand(MAP_WIDTH - 1), rand(MAP_HEIGHT - 1)
    if @map[x, y] == :empty
      @map[x, y] = :rabbit
      @rabbit = Rabbit.new(x, y)
    else
      new_rabbit
    end
  end

  def update_rabbit
    x, y = @rabbit.next_hop(*@rabbit.pos)
    if @map[x, y] == :empty
      @rabbit.pos = [x, y]
    else
      @rabbit.new_direction
    end
    @rabbit.distance -= 1
  end

  def update_snake
    @map[*@snake.update] = :empty
    @snake.body[1..-1].each { |x, y| @map[x, y] = :snake }
    # obviously the head should be :snake, but how to get it to work?
    # maybe if there is a next_head?
  end

  def snake_collide?
    (@map[*@snake.head] == :border) || (@map[*@snake.head] == :snake)
  end

  def update
    return if @paused

    if @snake.head == @rabbit.pos
      @snake.grow
      new_rabbit
    end
    update_snake
    update_rabbit

    if snake_collide?
      @paused = true
      new_game
    end
  end

  def draw
    draw_border
    draw_background
    draw_animal(@rabbit.pos, @rabbit.color, Z::Rabbit)
    @snake.body.each { |part| draw_animal(part, @snake.color, Z::Snake) }
  end

  def draw_border
    draw_quad(0, 0, BORDER_COLOR,
              WINDOW_WIDTH, 0, BORDER_COLOR,
              0, WINDOW_HEIGHT, BORDER_COLOR,
              WINDOW_WIDTH, WINDOW_HEIGHT, BORDER_COLOR,
              Z::Border)
  end

  def draw_background
    draw_quad(TILE_WIDTH,     TILE_WIDTH,      TOP_COLOR,
              WINDOW_WIDTH - TILE_WIDTH, TILE_WIDTH,      TOP_COLOR,
              TILE_WIDTH,     WINDOW_HEIGHT - TILE_WIDTH, BOTTOM_COLOR,
              WINDOW_WIDTH - TILE_WIDTH, WINDOW_HEIGHT - TILE_WIDTH, BOTTOM_COLOR,
              Z::Background)
  end

  def draw_animal(place, color, layer)
    draw_quad(place[0] * TILE_WIDTH, place[1] * TILE_WIDTH, color,
              place[0] * TILE_WIDTH + TILE_WIDTH, place[1] * TILE_WIDTH, color,
              place[0] * TILE_WIDTH, place[1] * TILE_WIDTH + TILE_WIDTH, color,
              place[0] * TILE_WIDTH + TILE_WIDTH, place[1] * TILE_WIDTH + TILE_WIDTH, color,
              layer)
  end

  def button_down(id)
    case id
    when Gosu::KbSpace  then @paused = !@paused
    when Gosu::KbEscape then close
    when Gosu::KbR      then new_game
    when Gosu::KbE      then @map.display
    end

    close if (button_down?(Gosu::KbLeftMeta) && button_down?(Gosu::KbQ))
    close if (button_down?(Gosu::KbRightMeta) && button_down?(Gosu::KbQ))

    @snake.direction(id)
  end
end


MambaSnakeGame.new.show

