require "sequel"
require "trie"
require 'lingua/stemmer'
require 'sanitize'

Stemmer= Lingua::Stemmer.new(:language => "en")

Whitelist = Trie.new

DB = Sequel.sqlite(ARGV[0])

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
    sum = all_t.inject(0) { |a, b| a + b.count }
    probs = all_t.map do |t|
      t.count / sum.to_f
    end
    all_t.zip(probs)
  end

  def self.generate
    start = nil
    words = []
    begin
      values = [0]
      set = next_set(start)
      set.each_with_index do |a, i|
        values << a.count + values[i]
      end
      ranges = []
      values[0..-2].each_with_index do |a, i|
        ranges << (values[i]..values[i+1])
      end

      r = rand(ranges.last.last + 1)
      i = ranges.index do |v|
        v === r
      end

      words << start
      start = set[i].right
    end until start == nil
    sentence = words.join(' ')
    sentence[1] = sentence[1].upcase
    sentence << '.'
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

case ARGV[1]
when "train"
  puts "Loading whitelist!"
  File.readlines("/usr/share/dict/words").each do |word|
    Whitelist.add Stemmer.stem(word.strip.downcase)
  end
  puts "Done!"

  while input = $stdin.gets
    Transition.train(Sanitize.fragment(input))
  end
when 'next'
  w = ARGV[2]
  Transition.next_with_prob(w.strip).each do |t|
    p t
  end
when "stats"
  puts Transition.count
when 'generate'
  sentences = []
  rand(10).times do
    sentences << Transition.generate
  end
  puts sentences.join ' '
when "debug"
  Transition.all.each do |t|
    p t
  end
end
