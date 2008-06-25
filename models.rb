require 'rubygems'
require 'chronic'

class Graph
  @@edges = {}
  @@nodes = []

  def self.connect(a, b, props)
    idx = [Graph.node(a), Graph.node(b)]
    @@edges[idx] ||= []
    @@edges[idx] << props
  end

  def self.node(name)
    @@nodes << name unless @@nodes.include? name
    name
  end

  def self.explore(node, constraints)
    Graph.new node, Graph.recurse(node, constraints, @@edges.keys)
  end

  def self.nodes
    @@nodes
  end

  def self.edges
    @@edges
  end

  def initialize(start, segments)
    @start = start
    @segments = segments
  end

  def dests
    segments = @segments.collect {|k| k.first.last }.uniq
    $stations.select { |station| segments.include? station['name'] }
  end

  def trains
    @segments.collect {|k| k.last[:train] }.uniq
  end

  def self.about(station, time, direction)
    segments = @@edges.keys.select {|k| k.first == station or k.last == station }
    foo = segments.collect do |segment|
      @@edges[segment].collect do |stop|
        if stop[:time] == time and stop[:direction] == direction
          if segment.first == station
            {stop[:train] => stop[:start]}
          else
            {stop[:train] => stop[:end]}
          end
        end
      end
    end.flatten.compact.uniq
    foo.collect do |dict|
      [dict.keys.first, dict[dict.keys.first]]
    end.sort {|x,y| x.last <=> y.last }.uniq
  end

  def stops(dest)
    stops = @segments.select {|k| k.first.last == dest }
    stops.collect do |stop| 
      {
        :train => stop.last[:train],
        :end => stop.last[:end],
        :start => @@edges.collect { |k| 
          next unless k.first.first == @start
          k.last.collect { |p| p[:start] if p[:train] == stop.last[:train] } }.flatten.compact.first
      }
    end
  end

  protected

  def self.recurse(cur, constraints, edges_left)
    new_edges_left = edges_left.clone
    ans = []
    edges_left.each do |edge|
      next unless edge.first == cur
      @@edges[edge].each do |props|
        next unless constraints.keys.collect { |k| props[k] == constraints[k] }.all?
        ans += [[edge, props]]
        new_edges_left.delete edge
        ans += Graph.recurse(edge.last, {:time => props[:time], :direction => props[:direction], :train => props[:train]}, new_edges_left)
      end
    end
    ans.uniq
  end
end

$times = [:weekdays, :weekends]
$directions = [:north, :south] 

$times.each do |time|
  $directions.each do |direction|

    # PARSE THE HTML

    data = open("tables/#{time}-#{direction}.html").read
    data = data.gsub(/<([^ \>]+)[^>]*>/,"<\\1>").gsub(/&nbsp;?/,' ').gsub('>-<','><').gsub(/<\/?sup>/, '').gsub(/<\/?a>/,'').gsub('*','').gsub(/@/, '').gsub('<br>', ' ').gsub('#', '')
    data = data.gsub(/\n/m, '').gsub(/\s+/, ' ').gsub(/ </, '<').gsub(/> /, '>')
    data = data.split('<tr>').slice(1..-1).collect{ |row| row.split(/<\/tr>/).first }
    data = data.collect do |row|
      row = row.split(/<\/t[hd]>/).collect do |cell| 
        cell.gsub(/<[^>]*>/, '') 
      end
      row = row.slice(0..-2) if row.first == row.last
      row unless row.first.include? 'Shuttle' 
    end.compact
    lengths = data.collect { |row| row.length }
    if lengths.max != lengths.min
      puts "error on #{time}-#{direction}" + data.collect { |row| row.length }.join(' ')
    end

    # BUILD THE GRAPH

    min_col_time = Chronic.parse('0:00')
    data.first.each_with_index do |train, column|
      next if column == 0
      # train.gsub!(/[^0-9]/,'')

      start_time = nil
      start_station = nil
      min_cur_time = nil
      data.each_with_index do |row, idx2|
        next if idx2 == 0
        next if row[column] == ''
        cur_time = Chronic.parse(row[column])
        while cur_time < min_col_time or (start_time && start_time > cur_time)
          cur_time += 60*60*12
        end
        min_cur_time ||= cur_time
        cur_station = row[0]
        if start_time
          Graph.connect(start_station, cur_station, {:direction => direction, :time => time, :train => train, :start => start_time, :end => cur_time})
        end
        start_time = cur_time
        start_station = cur_station
      end
      min_col_time = min_cur_time - 3*60*60
    end
  end
end

open('tables/stations.txt') do |f|
  $stations = f.collect do |l|
    l = l.slice(0..-2).split(',').collect{|cell| cell.gsub(/^ +/, '').gsub(/ +$/, '')}
    {'name' => l[0], 'address' => l[1] + ', ' + l[2] + ', CA ' + l[3] }
  end
end

Graph.nodes.each do |station|
  puts "error: missing #{station}" unless $stations.collect{|s| s['name'] }.include? station
end

# p Graph.about('Palo Alto', :weekdays, :north)
# explore = Graph.explore('San Francisco', {:time => :weekdays})
# puts explore.dests
# puts explore.trains
# puts explore.stops(explore.dests.last).length
