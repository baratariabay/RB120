class Rock
  @@id = :r
  @@beats = [:l, :sc ]

  def self.id
    @@id
  end

  def self.beats
    @@beats
  end

  def self.compare(other)
    if @@beats.include? other.id
      :win
    elsif other.beats.include? @@id
      :lose
    else
      :tie
    end
  end
end

class Paper
  @@id = :p
  @@beats = [:r, :sp]

  def self.id
    @@id
  end

  def self.beats
    @@beats
  end

  def self.compare(other)
    if @@beats.include? other.id
      :win
    elsif other.beats.include? @@id
      :lose
    else
      :tie
    end
  end
end

puts Rock.compare(Paper)
#=> lose