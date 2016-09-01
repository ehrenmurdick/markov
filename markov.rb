require "sequel"
require "trie"
require 'lingua/stemmer'

Stemmer= Lingua::Stemmer.new(:language => "en")

Whitelist = Trie.new

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
      input.delete_if do |w|
        !Whitelist.has_key?(Stemmer.stem(w))
      end

      input.each_with_index do |right, i|
        left = input[i - 1]
        left = nil if i == 0
        next if left == nil && right == nil
        t = find_or_create(left: left, right: right)
        t.increment!
      end

      t = find_or_create(left: input.last, right: nil)
      t.increment!
      print '.'
    end

    t = find(left: nil, right: nil)
    t.destroy if t
  end

  def self.next_set(word)
    where(left: word).all
  end

  def self.next_with_prob(word)
    all_t = next_set(word)
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
  puts "Loading whitelist!"
  File.readlines("/usr/share/dict/words").each do |word|
    Whitelist.add Stemmer.stem(word.strip.downcase)
  end
  puts "Done!"

  while input = $stdin.gets
    Transition.train(input)
  end
when 'next'
  w = ARGV[1]
  Transition.next_set(w.strip).each do |t|
    p t
  end
when "stats"
  puts Transition.count
when "debug"
  Transition.all.each do |t|
    p t
  end
end
