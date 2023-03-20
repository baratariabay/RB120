require 'yaml'

MSG = YAML.load_file('rps_display.yml')
CPU = YAML.load_file('ai_config.yml')
GOAL = 3

class Interface
  attr_reader :hands, :outcomes, :welcome

  def initialize
    @welcome = MSG['welcome']
    @opponent = MSG['computer']
    @thanks = MSG['end_frame']
    convert_hashes
  end

  def display_intro_seq
    puts `clear`
    sleep(0.5)
    puts welcome
    sleep(0.5)
    flash_hands(0.25)
  end

  def display_dialogue(phrase = '')
    puts `clear`
    screen_insert = "|   |".rjust(16) + phrase.center(41) + "|   |"
    puts [@opponent[0], screen_insert, @opponent[1]]
    sleep(2)
  end

  def display_battle_seq(player, computer)
    battle_intro
    puts `clear`
    puts render_battle(hands[player], hands[computer])
    sleep(1)
  end

  def display_result_seq(winner, phrase)
    result = winner.class == Human ? :win : :lose
    puts `clear`
    puts outcomes[result]
    sleep(1)
    display_dialogue(phrase)
    sleep(1)
  end

  def display_tie
    puts `clear`
    puts battle[:tie]
    sleep(1)
  end

  def display_score(scores, records)
    scoreboard_elements = compile_scoreboard_elements(scores, records)
    puts `clear`
    puts scoreboard[:line]
    scoreboard_elements.each do |content|
      puts content
      puts scoreboard[:line]
    end
    sleep 3
  end

  def display_gameover_seq(result)
    if result == :win
      win_sequence
    else
      puts `clear`
      puts game_over[:lose]
    end
    sleep(1)
  end

  def display_end_frame
    puts `clear`
    puts thanks
    sleep(1)
    puts `clear`
  end

  private

  attr_reader :battle, :scoreboard, :game_over, :thanks

  def convert_hashes
    @outcomes = hashify(MSG['outcomes'])
    @battle = hashify(MSG['battle'])
    @scoreboard = hashify(MSG['scoreboard'])
    @game_over = hashify(MSG['game_over'])
    @hands = setup_hands(MSG['hands'])
  end

  def hashify(data)
    data.each_with_object({}) do |(key, graphic), new_hash|
      new_hash[key.to_sym] = graphic
    end
  end

  def setup_hands(hands_data)
    hands_data.each_with_object({}) do |(key, graphic), hand|
      hand[key.to_sym] = render(graphic)
    end
  end

  def render(graphic)
    max_length = graphic.max_by(&:size)
    max_length = max_length.size
    graphic.map { |line| line.ljust(max_length) }
  end

  def flash_hands(speed)
    hands.each_value do |hand|
      puts `clear`
      puts hand
      sleep(speed)
    end
  end

  def battle_intro
    flash_hands(0.2)
    puts `clear`
    puts battle[:go]
    sleep(0.4)
  end

  def render_battle(hand1, hand2)
    frame = []
    8.times do |line|
      frame << hand1[line] + battle[:vs][line] + hand2[line]
    end
    frame
  end

  def render_header(names)
    format(scoreboard[:header],
           player1: names[0].to_s.center(25),
           player2: names[1].to_s.center(25))
  end

  def render_row(round, data)
    format(scoreboard[:row],
           round: round.to_s.center(7),
           player1: data[:human].to_s.center(25),
           player2: data[:computer].to_s.center(26),
           result: data[:result].center(13))
  end

  def render_total(points)
    format(scoreboard[:total],
           player1: points[0].to_s.center(25),
           player2: points[1].to_s.center(26))
  end

  def render_footer(goal)
    format(scoreboard[:footer], goal: goal)
  end

  def compile_scoreboard_elements(scores, records)
    elements = []
    elements << render_header(scores.keys)
    records.each_pair do |round, data|
      elements << render_row(round, data)
    end
    elements << render_total(scores.values)
    elements << render_footer(GOAL)
    elements
  end

  def win_sequence
    3.times do
      flash_fireworks
      puts `clear`
      puts game_over[:winner3]
      sleep(0.3)
    end
  end

  def flash_fireworks
    5.times do
      puts `clear`
      puts game_over[:winner1]
      sleep(0.1)
      puts `clear`
      puts game_over[:winner2]
      sleep(0.1)
    end
  end
end

class Move
  attr_reader :value, :graphic

  HANDS = {
    rock: { name: "Rock", beats: ["Lizard", "Scissors"] },
    paper: { name: "Paper", beats: ["Rock", "Spock"] },
    scissors: { name: "Scissors", beats: ["Paper", "Lizard"] },
    lizard: { name: "Lizard", beats: ["Paper", "Spock"] },
    spock: { name: "Spock", beats: ["Rock", "Scissors"] }
  }

  def initialize(value)
    @value = HANDS[value]
  end

  def >(other_move)
    @value[:beats].include? other_move.value[:name]
  end

  def <(other_move)
    other_move.value[:beats].include? value[:name]
  end

  def to_s
    @value[:name]
  end

  def to_sym
    HANDS.key(value)
  end
end

class Player
  attr_accessor :move, :name

  def initialize
    @move = nil
  end
end

class Human < Player
  def initialize
    super
    setup_name
  end

  def setup_name
    prompts = MSG['name']
    response = ''
    loop do
      display_question(prompts['question'])
      response = gets.chomp
      break if valid_name?(response)
      display_rejection(prompts['reject'])
    end
    self.name = response
  end

  def choose
    response = get_user_response(MSG['choice'])
    self.move = Move.new(response)
  end

  def play_again?
    response = get_user_response(MSG['yes_no'])
    response == :yes
  end

  private

  def valid_name?(name_input)
    if name_input.delete(' ').empty? || name_input.size > 10
      false
    else
      true
    end
  end

  def get_user_response(prompts)
    options = prompts['answers']
    response = ''
    loop do
      display_question(prompts['question'])
      response = gets.chomp.downcase
      break if valid_choice?(response, options.keys)
      display_rejection(prompts['reject'])
    end
    response = interpret_choice(response, options)
  end

  def valid_choice?(choice_input, options)
    options.flatten.include?(choice_input)
  end

  def interpret_choice(choice_input, options)
    choice = options.keys.select do |option|
      option.include?(choice_input)
    end
    options[choice.first].to_sym
  end

  def display_question(question)
    puts `clear`
    puts question
  end

  def display_rejection(message)
    puts message
    sleep(1)
  end
end

class Computer < Player
  attr_reader :win_lines, :lose_lines, :stats, :greeting

  def initialize
    character = pick_character
    @name = character['name']
    @win_lines = character['win_lines']
    @lose_lines = character['lose_lines']
    @stats = setup_stat_ranges(character['stats'])
    @greeting = character['greeting']
    super
  end

  def choose
    num = Random.rand(100)
    choice = case num
             when stats["rock"] then :rock
             when stats["paper"] then :paper
             when stats["scissors"] then :scissors
             when stats["lizard"] then :lizard
             when stats["spock"] then :spock
             end
    self.move = Move.new(choice)
  end

  def reaction(winner)
    if winner.class == Computer
      win_lines.sample
    else
      lose_lines.sample
    end
  end

  private

  def pick_character
    selection = CPU.keys.sample
    CPU[selection]
  end

  def setup_stat_ranges(stats)
    start = 0
    stats.each_with_object({}) do |(move, points), ranges|
      ranges[move] = (start...start + points)
      start = ranges[move].end
    end
  end
end

class RPSGame
  def initialize
    @screen = Interface.new
    screen.display_intro_seq
    @human = Human.new
    reset_game
  end

  def run
    loop do
      screen.display_dialogue(computer.greeting)
      play_regular_mode
      screen.display_gameover_seq(end_result)
      break unless human.play_again?
      reset_game
    end
    screen.display_end_frame
  end

  private

  attr_reader :human, :computer, :scores, :roundcount, :screen
  attr_accessor :record

  def reset_game
    @computer = Computer.new
    @scores = initialize_scoreboard
    @roundcount = 0
    @record = {}
  end

  def initialize_scoreboard
    scoreboard = {}
    scoreboard[human.name] = 0
    scoreboard[computer.name] = 0
    scoreboard
  end

  def add_point(winner)
    scores[winner] += 1
  end

  def winner?
    find_winner ? true : false
  end

  def find_winner
    if human.move > computer.move
      human
    elsif human.move < computer.move
      computer
    end
  end

  def game_over?
    scores.value?(GOAL)
  end

  def end_result
    scores.key(GOAL) == human.name ? :win : :lose
  end

  def play_regular_mode
    loop do
      update_roundcount
      winner = face_off
      response = computer.reaction(winner)
      screen.display_result_seq(winner, response)
      record_result
      add_point(winner.name)
      screen.display_score(scores, record)
      break if game_over?
    end
  end

  def face_off
    loop do
      human.choose
      computer.choose
      screen.display_battle_seq(human.move.to_sym, computer.move.to_sym)
      break if winner?
      screen.display_tie
    end
    find_winner
  end

  def update_roundcount
    @roundcount += 1
  end

  def record_result
    outcome = human.move > computer.move ? "WIN" : "LOSE"
    record[roundcount] = { human: human.move,
                           computer: computer.move,
                           result: outcome }
  end
end

RPSGame.new.run
