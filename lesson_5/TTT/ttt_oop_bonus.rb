require 'yaml'
CONFIG = YAML.load_file('ttt.yml')

module Interactables
  def screen_clear
    system 'clear'
  end

  def get_num_from_user(content, max_number: nil)
    loop do
      choice = question_and_answer(content).to_i
      return choice if (1..max_number).include?(choice)
      reject_input
    end
  end

  def question_and_answer(content)
    display_frame(content)
    gets.chomp
  end

  def reject_input
    content = CONFIG['invalid_input']
    display_frame(content)
    sleep(0.5)
  end

  def display_frame(content)
    screen_clear
    puts content
  end
end

class Board
  WINNING_LINES = [[1, 2, 3], [4, 5, 6], [7, 8, 9]] +
                  [[1, 4, 7], [2, 5, 8], [3, 6, 9]] +
                  [[1, 5, 9], [3, 5, 7]]

  attr_reader :squares

  def initialize
    @squares = {}
    reset
  end

  def winning_lines
    WINNING_LINES
  end

  # rubocop: disable Metrics/AbcSize
  def to_s
    board = CONFIG["board"].join("\n")
    format(board,
           sq1: squares[1], sq2: squares[2], sq3: squares[3],
           sq4: squares[4], sq5: squares[5], sq6: squares[6],
           sq7: squares[7], sq8: squares[8], sq9: squares[9])
  end
  # rubocop: enable Metrics/AbcSize

  def []=(key, marker)
    @squares[key].marker = marker
  end

  def unmarked_keys
    @squares.keys.select { |key| @squares[key].unmarked? }
  end

  def full?
    unmarked_keys.empty?
  end

  def someone_won?
    !!winning_marker
  end

  def count_markers(marker, squares)
    squares.map(&:marker).count(marker)
  end

  # returns winning marker or nil
  def winning_marker
    WINNING_LINES.each do |line|
      squares = @squares.values_at(*line)
      if three_identical_markers?(squares)
        return squares.first.marker
      end
    end
    nil
  end

  def three_identical_markers?(squares)
    markers = squares.select(&:marked?).collect(&:marker)
    return false if markers.size != 3
    markers.min == markers.max
  end

  def reset
    (1..9).each { |key| @squares[key] = Square.new }
  end
end

class Square
  INITIAL_MARKER = " "

  attr_accessor :marker

  def initialize(marker=INITIAL_MARKER)
    @marker = marker
  end

  def to_s
    if [' ', '⭕️'].include?(marker)
      marker.center(5)
    else
      marker.center(4)
    end
  end

  def marked?
    marker != INITIAL_MARKER
  end

  def unmarked?
    marker == INITIAL_MARKER
  end
end

class Player
  @@selected_markers = []
  @@selected_avatars = []

  attr_reader :marker, :name, :avatar
  attr_accessor :wins

  def initialize
    @wins = 0
  end

  def to_s
    name_card = CONFIG['name_card'].join("\n")
    format(name_card,
           name: name.center(12),
           face: centre_avatar,
           marker: marker.center(1),
           wins: wins)
  end

  private

  def store_marker_selection
    @@selected_markers << marker
  end

  def store_avatar_selection
    @@selected_avatars << avatar
  end

  def centre_avatar
    faces = CONFIG['faces']
    case avatar
    when faces[2] then avatar.center(13)
    when faces[3] then avatar.center(15)
    when faces[5] then avatar.center(14)
    else
      avatar.center(12)
    end
  end
end

class Human < Player
  include Interactables

  def initialize
    super
    set_name
    select_marker
    select_avatar
  end

  def select_marker
    content = CONFIG['marker_options']
    choice = get_num_from_user(content, max_number: 8)
    @marker = CONFIG['markers'][choice]
    store_marker_selection
  end

  def select_avatar
    content = CONFIG['face_options']
    choice = get_num_from_user(content, max_number: 6)
    @avatar = CONFIG['faces'][choice]
    store_avatar_selection
  end

  def set_name
    content = CONFIG['enter_name']
    response = ''
    loop do
      response = question_and_answer(content)
      break if valid_name?(response)
      reject_input
    end
    @name = response
  end

  def valid_name?(name_input)
    !(name_input.delete(' ').empty? || name_input.size > 10)
  end
end

class Computer < Player
  attr_reader :board

  def initialize(board)
    @board = board
    @name = select_name
    @marker = select_marker
    @avatar = select_avatar
    super()
  end

  def choose_move(mode)
    if mode == :easy
      board.unmarked_keys.sample
    else
      make_strategic_choice
    end
  end

  private

  def select_name
    CONFIG['cpu_names'].sample
  end

  def select_marker
    loop do
      choice = CONFIG['markers'].values.sample
      return choice if marker_available?(choice)
    end
  end

  def select_avatar
    loop do
      choice = CONFIG['faces'].values.sample
      return choice if avatar_available?(choice)
    end
  end

  def marker_available?(choice)
    !@@selected_markers.include?(choice)
  end

  def avatar_available?(choice)
    !@@selected_avatars.include?(choice)
  end

  def make_strategic_choice
    if !offensive_options.empty?
      offensive_options.sample
    elsif !defensive_options.empty?
      defensive_options.sample
    elsif board.squares[5].unmarked?
      5
    else
      board.unmarked_keys.sample
    end
  end

  def offensive_options
    board.unmarked_keys.select do |key|
      available_sets = board.winning_lines.select { |line| line.include?(key) }
      available_sets.any? do |line|
        potential_win?(line)
      end
    end
  end

  def defensive_options
    board.unmarked_keys.select do |key|
      find_available_sets(key).any? do |line|
        potential_loss?(line)
      end
    end
  end

  def find_available_sets(key)
    board.winning_lines.select { |line| line.include?(key) }
  end

  def potential_win?(line)
    squares = board.squares
    total = squares.values_at(*line).count do |square|
      square.marker == marker
    end
    total == 2
  end

  def potential_loss?(line)
    squares = board.squares
    total = squares.values_at(*line).count do |square|
      square.marked? && square.marker != marker
    end
    total == 2
  end
end

class TTTGame
  include Interactables

  WIN_GOAL = { easy: 2, normal: 3 }

  def initialize
    @board = Board.new
    @starter = "Random"
    @mode = :easy
  end

  def play
    display_welcome_message
    setup_players
    main_menu
    display_goodbye_message
  end

  private

  attr_reader :board, :human, :computer, :current_player, :mode

  def setup_players
    @human = Human.new
    @computer = Computer.new(board)
  end

  def main_menu
    loop do
      case get_num_from_user(render_menu_interface, max_number: 3)
      when 2 then change_game_mode
      when 3 then change_starter
      when 1
        main_game
        break unless play_again?
      end
    end
  end

  def render_menu_interface
    components = [human.to_s, generate_menu_text, computer.to_s]
    components.map! { |component| component.split("\n") }
    render(components)
  end

  def generate_menu_text
    final_menu = CONFIG['menu'].join("\n")
    mode_text = @mode.to_s.capitalize.ljust(10)
    first_text = @starter.ljust(10)
    format(final_menu, mode: mode_text, first: first_text)
  end

  def change_game_mode
    content = CONFIG['mode_options']
    choice = get_num_from_user(content, max_number: 2)
    @mode = case choice
            when 1 then :easy
            when 2 then :normal
            end
  end

  def change_starter
    content = render_starter_options
    choice = get_num_from_user(content, max_number: 3)
    @starter = case choice
               when 1 then human.name
               when 2 then computer.name
               when 3 then "Random"
               end
  end

  def render_starter_options
    content = CONFIG['select_starter'].join("\n")
    human_name = human.name.ljust(10)
    computer_name = computer.name.ljust(10)
    format(content,
           human: human_name,
           computer: computer_name)
  end

  def main_game
    loop do
      play_match
      record_match_winner
      break if game_winner?
    end
    display_game_result
    reset_wins
  end

  def play_match
    reset
    display_board
    player_moves
    display_result
  end

  def record_match_winner
    winner = find_winner
    winner.wins += 1 if winner
  end

  def display_game_result
    content = CONFIG['game_result']
    if human.wins == WIN_GOAL[mode]
      play_animation(content['win'], loops: 6)
    else
      display_frame(content['lose'])
      sleep(1)
    end
  end

  def reset_wins
    human.wins = 0
    computer.wins = 0
  end

  def player_moves
    loop do
      current_player_moves
      display_board
      sleep(0.3)
      break if board.someone_won? || board.full?
    end
  end

  def current_player_moves
    if current_player == human
      human_moves
      @current_player = computer
    else
      computer_moves
      @current_player = human
    end
  end

  def display_options
    options = if board.unmarked_keys.size == 1
                board.unmarked_keys.first
              else
                board.unmarked_keys[0...-1].join(', ') +
                  " or #{board.unmarked_keys.last}"
              end
    puts "Choose a square (#{options}):"
  end

  def human_moves
    square = nil
    loop do
      display_options
      square = gets.chomp.to_i
      break if board.unmarked_keys.include?(square)
      reject_input
      display_board
    end

    board[square] = human.marker
  end

  def computer_moves
    choice = computer.choose_move(mode)
    board[choice] = computer.marker
  end

  def game_winner?
    human.wins == WIN_GOAL[mode] || computer.wins == WIN_GOAL[mode]
  end

  def display_result
    content = render_match_endframe
    display_frame(content)
    sleep(1)
  end

  def find_winner
    if board.winning_marker == human.marker
      human
    elsif board.winning_marker == computer.marker
      computer
    end
  end

  def render_match_endframe
    endframe = CONFIG['match_winner'].join("\n")

    winner = if board.someone_won?
               find_winner.name + " Won!"
             else
               "It's a tie"
             end
    format(endframe, winner: winner.center(14))
  end

  def starter
    if @starter == human.name
      human
    elsif @starter == computer.name
      computer
    else
      [computer, human].sample
    end
  end

  def display_welcome_message
    column = CONFIG['empty_box']
    frames = CONFIG['intro_seq']

    frames = frames.map do |frame|
      render([column, frame, column])
    end
    play_animation(frames)
  end

  def play_animation(frames, loops: 1)
    loops.times do
      frames.each do |content|
        display_frame(content)
        sleep(0.15)
      end
    end
  end

  def display_goodbye_message
    display_frame(CONFIG['outro'])
    sleep(1)
    screen_clear
  end

  def display_board
    components = [human.to_s, board.to_s, computer.to_s]
    components.map! { |component| component.split("\n") }
    screen_clear
    puts render(components)
  end

  def render(components)
    rendered_frame = []
    components.first.size.times do |line|
      rendered_line = ''
      components.each do |component|
        rendered_line << component[line]
      end
      rendered_frame << rendered_line
    end
    rendered_frame
  end

  def play_again?
    answer = nil
    loop do
      display_frame(CONFIG['play_again'])
      answer = gets.chomp.downcase
      break if %w(y n).include? answer
      reject_input
    end

    answer == "y"
  end

  def reset
    board.reset
    @current_player = starter
  end
end

game = TTTGame.new
game.play
