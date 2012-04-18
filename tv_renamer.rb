#!/usr/bin/env ruby

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
    new_name = "#{show} - S#{n>9 ? n : '0'+n.to_s}E#{ep>9 ? ep : '0'+ep.to_s}.#{ext}"
    puts "Rename \"#{item}\" to \"#{new_name}\"? [yes/no]"
    yn = gets.chomp
    if /^y(?:(?:es)|$)/i.match(yn)
      begin
        File.rename("#{dir}/#{item}", "#{dir}/#{new_name}")
        puts "File renamed."
      rescue
        puts "There was a problem renaming this file. File skipped."
      end
    else
      puts "File skipped."
    end
  end
end

subdirs = Dir.glob("*/").reject{|x| /^Season (\d+)\/$/i.match(x).nil? }
if subdirs.count > 0 # season subdirs
  subdirs.each do |s|
    next unless (season = /^Season (\d+)\/$/i.match(s)) && season.length > 1
    rename_season(season[1].to_i)
  end
else # multiple seasons
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