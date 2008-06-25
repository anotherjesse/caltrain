require 'rubygems'
require 'json'
require 'erb'
require 'rexml/document'
require 'models'


index_template = ERB.new File.open('templates/index.html.erb').read
about_template = ERB.new File.open('templates/about.html.erb').read
from_template = ERB.new File.open('templates/from.html.erb').read
to_template = ERB.new File.open('templates/to.html.erb').read
station_template = ERB.new File.open('templates/station.html.erb').read
station_list_template = ERB.new File.open('templates/station_list.html.erb').read
time_template = ERB.new File.open('templates/time.html.erb').read

File.open("build/index.html", 'w') { |f| f.write index_template.result(binding) }
File.open("build/about.html", 'w') { |f| f.write about_template.result(binding) }

$stations.each do |station|
  File.open("build/#{station['name']}.html", 'w') { |f| f.write station_template.result(binding) }
end

File.open("build/stations.html", 'w') { |f| f.write station_list_template.result(binding) }

$times.each do |time|

  stations = Graph.nodes.collect do |station|
    puts "Generating #{time} for #{station}"
    explore = Graph.explore(station, {:time => time})
    dests = explore.dests

    File.open("build/#{time}_#{station}.html", 'w') { |f| f.write from_template.result(binding) }
    dests.each do |dest|

      stops = explore.stops(dest['name'])
      rev_url = "#{time}_#{dest['name']}_#{station}.html"
      File.open("build/#{time}_#{station}_#{dest['name']}.html", 'w') { |f| f.write to_template.result(binding) }
    end

    if dests.length > 0
      station
    else 
      nil
    end
  end.compact

  stations = $stations.select { |station| stations.include? station['name'] }

  File.open("build/#{time}.html", 'w') { |f| f.write time_template.result(binding) }
end

`cp templates/custom.css build/custom.css`
`cp -r iui build/iui`

