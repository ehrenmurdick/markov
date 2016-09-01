require "sequel"

DB = Sequel.sqlite('model.sqlite')

DB.create_table? :transitions do
  primary_key :id
  String :left
  String :right
  Int :count
end


class Transition < Sequel::Model

  def self.clean(string)
    string.downcase.gsub(/[^a-z .]/, '')
  end

  def self.train(string)
    lines = string.split(".")
    lines.each do |line|
      input = clean(line).split

      input.each_with_index do |right, i|
        left = input[i - 1]
        left = nil if i == 0
        t = find_or_create(left: left, right: right)
        t.increment!
      end

      t = find_or_create(left: input.last, right: nil)
      t.increment!
    end
  end

  def increment!
    self.count ||= 0
    self.count += 1
    save
  end

  def inspect
    "#{left} -> #{right} [#{count}]"
  end
end

case ARGV[0]
when "train"
  input = File.read(ARGV[1])
  Transition.train(input)
when "stats"
  puts Transition.count
when "debug"
  Transition.all.each do |t|
    p t
  end
end
