require 'yaml'
require 'pry'
CONFIG = YAML.load_file('21.yml')

module Renderables
  # creates a composition from multiple string 'graphics'
  #  where the input graphics are layed out side-by-side
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
end

module Displayables
  def display_table(console = nil)
    console = CONFIG['spacer'] if !console

    puts `clear`
    display_cards(dealer)
    puts "\n\n"
    display_cards(human)

    puts render([console, scoreboard_display])
  end

  def display_cards(player)
    puts player.class.to_s.capitalize
    if player.hand.total != 0
      puts player.render_hand
      puts "Total: #{player.total}"
    else
      puts "\n\n\n\n\n\n"
    end
  end

  def outcome_animation(result)
    animation = CONFIG[result]
    animation.each do |frame|
      display_table(frame)
      sleep(0.1)
    end
    sleep(0.15)
  end

  def message(text)
    template = CONFIG['console'].join("\n")
    formatted = format(template, text: text.center(30))
    formatted.split("\n")
  end

  def scoreboard_display
    template = CONFIG['score'].join("\n")
    points = score.to_s.center(3)
    graphic = format(template, score: points)
    graphic.split("\n")
  end

  def play_intro_animation
    animation = CONFIG['intro_animation']
    animation.each_with_index do |frame, seq_number|
      puts `clear`
      puts frame
      delay = seq_number.even? ? 0.4 : 0.16
      sleep(delay)
    end
    sleep(0.6)
  end

  def error_message
    alert = message("INVALID INPUT")
    display_table(alert)
    sleep(0.5)
  end

  def display_options
    display_table(CONFIG['options'])
  end

  def display_stay(player)
    text = message("'#{player.class} stayed on #{player.total}'")
    puts `clear`
    display_table(text)
    sleep(0.75)
  end

  def display_endgame(score)
    puts `clear`
    template = CONFIG['deck_finished'].join("\n")
    puts format(template, score: score.to_s.center(32))
  end

  def display_outro
    puts `clear`
    puts CONFIG['outro']
    sleep(2)
    puts `clear`
  end

  def reveal_topcard
    dealer.turn = true
    text = message("'#{dealer.total}'")
    display_table(text)
    sleep(0.5)
  end

  def display_rescue
    puts `clear`
    puts CONFIG['rescue']
    sleep(1.5)
  end

  def display_rejection
    puts `clear`
    puts CONFIG['rejection']
    sleep(0.75)
  end
end

class Card
  attr_reader :suit, :value

  def initialize(suit, value)
    @suit = suit
    @value = value
  end

  def to_s
    template = CONFIG['cards'][suit].join("\n")
    card_value = value.to_s.ljust(2)
    format(template, value: card_value)
  end

  def real_value
    if value == 'A'
      11
    elsif ['J', 'Q', 'K'].include?(value)
      10
    else
      value
    end
  end
end

class Deck
  SUITS = ['spades', 'clubs', 'diamonds', 'hearts']
  FACES = ['J', 'Q', 'K', 'A']

  def initialize
    @cards = create_deck
    @cards.shuffle!
  end

  def draw_card
    @cards.pop
  end

  def size
    @cards.size
  end

  private

  def create_deck
    cards = []
    SUITS.each do |suit|
      (2..10).each { |number| cards << Card.new(suit, number) }
      FACES.each { |face| cards << Card.new(suit, face) }
    end
    cards
  end
end

class Hand
  attr_reader :cards

  def initialize
    @cards = []
    @total = 0
  end

  def <<(card)
    cards << card
    @total = update_total
  end

  def as_strings
    cards.map(&:to_s)
  end

  def total
    if @total <= 21
      @total
    else
      'bust'
    end
  end

  private

  def update_total
    aces = 0
    new_total = 0
    cards.each do |card|
      new_total += card.real_value
      aces += 1 if card.value == 'A'
    end
    adjust_aces(new_total, aces)
  end

  def adjust_aces(total, aces)
    aces.times do
      total -= 10 if total > 21
    end
    total
  end
end

class Player
  include Renderables
  attr_reader :hand

  def initialize
    @hand = Hand.new
  end

  def busted?
    hand.total == 'bust'
  end

  def total
    hand.total
  end

  def render_hand
    graphic = hand.as_strings.map do |card|
      card.split("\n")
    end

    render(graphic)
  end

  def choose_option
    choice = gets.chomp.downcase
    if choice == 'hit'
      :hit
    elsif choice == 'stay'
      :stay
    else
      :invalid
    end
  end

  def clear_hand
    @hand = Hand.new
  end
end

class Dealer < Player
  attr_accessor :turn

  def initialize
    super
    @turn = false
  end

  def render_hand
    graphic = hand.as_strings.map do |card|
      card.split("\n")
    end
    if @turn || hand.cards.size == 1
      render(graphic)
    else
      blank_card = CONFIG['blank_card']
      render([graphic[0], blank_card])
    end
  end

  def total
    if @turn
      super
    else
      hand.cards.first.real_value
    end
  end

  def choose_option
    if hand.total < 17
      :hit
    else
      :stay
    end
  end
end

class Game
  include Renderables, Displayables

  def initialize
    @human = Player.new
    @dealer = Dealer.new
  end

  def start
    play_intro_animation
    loop do
      reset_game
      play_through_deck
      break if deck.size > 12 || !play_again?
    end
    display_outro
  end

  private

  attr_reader :human, :dealer, :deck, :score

  def play_through_deck
    loop do
      card_game
      break if deck.size <= 12 || quit_game?
      clear_hands
    end
  end

  def card_game
    deal_opening_hands
    play_turn(human)
    play_turn(dealer) unless human.busted?
    update_score
    show_result
  end

  def deal_opening_hands
    display_table
    sleep(0.3)
    2.times do
      [human, dealer].each do |player|
        deal_card(player)
      end
    end
  end

  # rubocop: disable Metrics/MethodLength, Metrics/AbcSize
  def deal_card(player)
    player.hand << deck.draw_card
    if player == dealer && !dealer.turn
      display_table
    else
      text = message("'#{player.total}'")
      display_table(text)
    end
    sleep(0.75)
  rescue NoMethodError
    player.hand.cards.pop
    @deck = Deck.new
    display_rescue
    retry
  end
  # rubocop: enable Metrics/MethodLength, Metrics/AbcSize

  def play_turn(player)
    reveal_topcard if player == dealer
    while player.total != "bust"
      display_options if player == human
      case player.choose_option
      when :hit then deal_card(player)
      when :stay then break display_stay(player)
      when :invalid then error_message
      end
    end
  end

  def show_result
    case find_winner
    when human then outcome_animation('winner')
    when dealer then outcome_animation('loser')
    else
      display_table(message('"Tie!"'))
      sleep(1)
    end
  end

  def find_winner
    return bust_winner if bust_winner

    if human.total > dealer.total
      human
    elsif human.total < dealer.total
      dealer
    end
  end

  def bust_winner
    return dealer if human.busted?
    return human if dealer.busted?
  end

  def update_score
    @score += 1 if find_winner == human
    @score -= 1 if find_winner == dealer
  end

  def quit_game?
    text = CONFIG['quit_screen']
    display_table(text)
    answer = gets.chomp.downcase
    answer == 'no'
  end

  def play_again?
    answer = ''
    loop do
      display_endgame(score)
      answer = gets.chomp.downcase
      break if ['yes', 'no'].include?(answer)
      display_rejection
    end
    answer == 'yes'
  end

  def reset_game
    @deck = Deck.new
    clear_hands
    @score = 0
  end

  def clear_hands
    human.clear_hand
    dealer.clear_hand
    dealer.turn = false
  end
end

Game.new.start
