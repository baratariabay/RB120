class Board
  attr_reader :squares

  WINNING_LINES = [[1, 2, 3], [4, 5, 6], [7, 8, 9]] + # rows
                  [[1, 4, 7], [2, 5, 8], [3, 6, 9]] + # cols
                  [[1, 5, 9], [3, 5, 7]]              # diagonals
  def initialize(human, computer)
    @squares = {}
    @human_marker = human
    @computer_marker = computer
    reset
  end

  # rubocop: disable Metrics/AbcSize
  # rubocop: disable Metrics/MethodLength
  def draw
    puts "     |     |"
    puts "  #{squares[1]}  |  #{squares[2]}  |  #{squares[3]}"
    puts "     |     |"
    puts "-----+-----+-----"
    puts "     |     |"
    puts "  #{squares[4]}  |  #{squares[5]}  |  #{squares[6]}"
    puts "     |     |"
    puts "-----+-----+-----"
    puts "     |     |"
    puts "  #{squares[7]}  |  #{squares[8]}  |  #{squares[9]}"
    puts "     |     |"
  end
  # rubocop: enable Metrics/AbcSize
  # rubocop: enable Metrics/MethodLength

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
      return @human_marker if count_markers(@human_marker,
                                            squares.values_at(*line)) == 3
      return @computer_marker if count_markers(@computer_marker,
                                               squares.values_at(*line)) == 3
    end
    nil
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
    @marker
  end

  def unmarked?
    marker == INITIAL_MARKER
  end
end

class Player
  attr_reader :marker

  def initialize(marker)
    @marker = marker
  end
end

class TTTGame
  HUMAN_MARKER = "X"
  COMPUTER_MARKER = "O"

  def initialize
    @human = Player.new(HUMAN_MARKER)
    @computer = Player.new(COMPUTER_MARKER)
    @board = Board.new(human.marker, computer.marker)
    @current_player = human
  end

  def play
    screen_clear
    display_welcome_message
    main_game
    display_goodbye_message
  end

  private

  attr_reader :board, :human, :computer, :current_player

  def main_game
    loop do
      display_board
      player_moves
      display_result
      break unless play_again?
      reset
      display_play_again_message
    end
  end

  def display_welcome_message
    puts "welcome to tic tac toe"
  end

  def display_goodbye_message
    puts 'thanks for playing tic tac toe'
  end

  def display_board
    puts "You're a #{HUMAN_MARKER}. Computer is #{COMPUTER_MARKER}."
    board.draw
  end

  def clear_screen_and_display_board
    screen_clear
    display_board
  end

  def player_moves
    loop do
      current_player_moves
      break if board.someone_won? || board.full?
      clear_screen_and_display_board
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

  def human_moves
    puts "Choose a square (#{board.unmarked_keys.join(', ')}):"
    square = nil
    loop do
      square = gets.chomp.to_i
      break if board.unmarked_keys.include?(square)
      puts "invalid choice"
    end

    board[square] = human.marker
  end

  def computer_moves
    square = board.unmarked_keys.sample
    board[square] = computer.marker
  end

  def display_result
    clear_screen_and_display_board
    case board.winning_marker
    when HUMAN_MARKER
      puts "you won"
    when COMPUTER_MARKER
      puts "computer won"
    else
      puts "it's a tie"
    end
  end

  def play_again?
    answer = nil
    loop do
      puts "would you like to play again? (y/n)"
      answer = gets.chomp.downcase
      break if %w(y n).include? answer
      puts "sorry must be y or n"
    end

    answer == "y"
  end

  def reset
    board.reset
    screen_clear
    @current_player = human
  end

  def display_play_again_message
    puts "Let's play again!"
    puts ""
  end

  def screen_clear
    system 'clear'
  end
end

game = TTTGame.new
game.play
