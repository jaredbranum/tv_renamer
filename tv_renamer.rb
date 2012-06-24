#!/usr/bin/env ruby
require 'rubygems'
require 'yaml'
require 'uri'
require 'open-uri'
require 'nokogiri'
require 'zipruby'

$settings = {
  :use_title => true,
  :force_title => false,
  :ask_every_time => true,
  :silent => false
}
def process_arg(arg)
  case arg
  when 'f', 'force-title' then $settings[:force_title] = true
  when 'n', 'no-title' then $settings[:use_title] = false
  when 'y', 'yes' then $settings[:ask_every_time] = false
  when 's', 'silent' then $settings[:silent] = true
  end
end
ARGV.each do |a|
  if a.length == 1
    process_arg(a)
  elsif a.length > 2 && a[0..1] == '--'
    process_arg(a[2..-1])
  elsif a[0].chr == '-'
    a[1..-1].each_char{|c| process_arg(c) }
  end
end
$settings[:use_title] = true if $settings[:force_title]

if $settings[:use_title]
  yaml_path = File.join(File.expand_path(File.dirname(__FILE__)), 'api.yaml')
  api_yaml = YAML::load(File.open(yaml_path))['thetvdb']
  API_PATH = api_yaml['path']
  API_KEY = api_yaml['key']
end
if $settings[:silent]
  def puts(s)
    nil
  end
end

def rename_season(n=1)
  show = File.basename(Dir.pwd)
  dir = "#{Dir.pwd}/Season #{n}"
  ep = 0
  Dir.foreach(dir) do |item|
    next if item[0].chr == '.'
    if matchdata = /s?\d+[ex](\d+)/i.match(item)
      ep = matchdata[1].to_i
    else
      ep += 1
    end
    ext = item[/\.([^\.]+)$/,1]
    ep_title = if $settings[:force_title]
      title = nil
      while title.nil? do
        title = get_title(show, n, ep)
      end
      title
    else
      $settings[:use_title] ? get_title(show, n, ep) : nil
    end
    new_name = if ep_title
      "#{show} - S#{pad_zero(n)}E#{pad_zero(ep)} - #{ep_title}.#{ext}"
    else
      "#{show} - S#{pad_zero(n)}E#{pad_zero(ep)}.#{ext}"
    end
    next if item == new_name
    if $settings[:ask_every_time]
      puts "Rename \"#{item}\" to \"#{new_name}\"? [yes/no]"
      yn = gets.chomp
      confirm = /^y(?:(?:es)|$)/i.match(yn)
    else
      confirm = true
    end
    if confirm
      begin
        File.rename("#{dir}/#{item}", "#{dir}/#{new_name}")
        puts "-" * 10
        puts "#{item}"
        puts "renamed to"
        puts "#{new_name}"
        puts "-" * 10
      rescue
        puts "There was a problem renaming this file. File skipped."
      end
    else
      puts "File skipped."
    end
  end
end

@episode_title_cache = {}
def populate_cache(series)
  series_xml = open("#{API_PATH}GetSeries.php?seriesname=#{URI.encode(series)}")
  doc = Nokogiri::XML(series_xml.read)
  node = doc.xpath('/Data/Series/seriesid').first
  return false if node.nil?
  series_id = node.content
  series_zip = open("#{API_PATH}#{API_KEY}/series/#{series_id}/all/en.zip")
  @episode_title_cache[series] = {}
  Zip::Archive.open(series_zip.path) do |zf|
    zf.fopen('en.xml') do |f|
      doc = Nokogiri::XML(f.read)
      @node = doc.xpath('/Data/Episode')
      @node.each do |ep_node|
        season_num = ep_node.xpath('SeasonNumber').first.content.to_i
        episode_num = ep_node.xpath('EpisodeNumber').first.content.to_i
        ep_title = ep_node.xpath('EpisodeName').first.content
        unless @episode_title_cache[series].has_key?(season_num)
          @episode_title_cache[series][season_num] = {}
        end
        @episode_title_cache[series][season_num][episode_num] = ep_title
      end
    end
  end
end

def get_title(series, season, ep)
  unless @episode_title_cache.has_key?(series)
    populate_cache(series)
  end
  @episode_title_cache[series][season.to_i][ep.to_i]
end

def pad_zero(n)
  n = n.to_i
  n > 9 ? n.to_s : "0#{n}"
end

subdirs = Dir.glob("*/").reject{|x| /^Season (\d+)\/$/i.match(x).nil? }
if subdirs.count > 0 # season subdirs (multiple seasons)
  subdirs.each do |s|
    next unless (season = /^Season (\d+)\/$/i.match(s)) && season.length > 1
    rename_season(season[1].to_i)
  end
else # single season
  if season = /^Season (\d+)$/i.match(File.basename(Dir.pwd))
    Dir.chdir("..")
    rename_season(season[1].to_i)
  else
    puts "No season subdirectories or episodes found. Be sure you run " +
    "tv_renamer.rb from the root directory of the show you want to rename, " +
    "or from within a season directory."
    exit(1)
  end
end
puts "Renaming complete."