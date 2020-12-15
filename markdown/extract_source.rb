#!/usr/bin/ruby

require 'optparse'

opt_debug = false
out_file = ""
in_file = ""
repo_dir = ""
source_dir = ""

opt = OptionParser.new
opt.on('-d', '--debug', "Debug") { opt_debug = true }
opt.on('-o', '--output ITEM', "Output File") {|v| out_file = v}
opt.on('-i', '--input ITEM', "Input File") {|v| puts v; in_file = v }
opt.on('-s', '--source ITEM', "Sample Source Directory") {|v| source_dir = v}
opt.on('-r', '--repo ITEM', "Repo Directory") {|v| repo_dir = v}

opt.parse(ARGV)

text = nil
if in_file == "" then
  text = readline
else
  text = File.open(in_file).read
end

if out_file == "" then
  out_fp = STDIN
else
  out_fp = File.open(out_file, "w")
end


# Atfirst allowing to write output file

text.each_line {|line|
  if line =~ /@whole:([^:]*):\s*([\w\._\/]+)/ then
    lang = $1
    filename = $2

    puts "Found While Program. Language = #{lang}, Target Source = " + filename + "\n"

    command_string = "git find " + filename

    file_location = ""
    code_text = ""
    Dir.chdir(source_dir) {
      file_location = %x[#{command_string}]
    }
    command_string = "cat " + file_location
    code_text = %x[#{command_string}]

    out_fp.print "[//]: <> (" + "Code: Tag = " + filename + ")\n"
    out_fp.print "- `" + file_location.gsub(/#{source_dir}\//,'') + "`\n"
    out_fp.print "```" + lang + "\n"
    out_fp.print code_text
    out_fp.print "```\n"

  elsif line =~ /@code:([^:]*):\s*([\w\._\/]+)/ then
    lang = $1
    target_label = $2

    start_line = -1
    stop_line = -1
    Dir.chdir(source_dir) {
      command_string = "git grep -E -n \"\@\\{ \*" + target_label + "$\" "
      start_line = %x[#{command_string}]
    }
    Dir.chdir(source_dir) {
      command_string = "git grep -E -n \"@\} \*" + target_label + "$\" "
      stop_line = %x[#{command_string}]
    }
    file_location = start_line.split(':')[0]
    start_line = start_line.split(':')[1].to_i
    stop_line  = stop_line.split(':')[1].to_i

    command_string = "head -n " + (stop_line - 1).to_s + " " + file_location \
                     + " | " + "tail -n +" + (start_line + 1).to_s + " | grep -v @{ | grep -v @}"
    code_text = ""
    Dir.chdir(source_dir) {
      code_text = %x[#{command_string}]
    }
    out_fp.print "[//]: <> (" + "Code: Tag = " + target_label + ")\n"
    out_fp.print "- `" + file_location.gsub(/#{source_dir}\//,'') + "`\n"
    out_fp.print "```" + lang + "\n"
    out_fp.print code_text
    out_fp.print "```\n"

  elsif line =~ /@ref:([^:]*):\s*([\w\._\/]+)/ then

    lang = $1
    target_label = $2

    if opt_debug == true then
      puts "Found Tag. Language = #{lang}, Message = " + target_label + "\n"
    end

    command_string = "git log --name-only --oneline -n 1 --since '2020/04/01' --pickaxe-regex -S\"" + target_label + "$\""

    git_log_result = ""
    Dir.chdir(repo_dir) {
      git_log_result = %x[#{command_string}]
    }

    revision = git_log_result.split(" ")[0]
    commit_log = git_log_result.split(" ").drop(1)
    if opt_debug == true then
      puts "  Commit Log = #{commit_log}"
    end
    # command_string = "git checkout " + revision
    # Dir.chdir(repo_dir) {
    #   git_exec_result = %x[#{command_string}]
    # }

    if commit_log == [] then
      out_fp.print "[//]: <> " + "\"Message = " + target_label + " not found\"\n"
      next
    end

    Dir.chdir(repo_dir) {
      git_log_result.split("\n").drop(1).each {|file|

        command_string = "git show " + revision + ":" + file + " | grep -E -n \"@{ *" + target_label + "$\" "
        if opt_debug == true then
          puts "Command = " + command_string
        end
        start_line = `#{command_string}`
        command_string = "git show " + revision + ":" + file + " | grep -E -n \"@} *" + target_label + "$\" "
        stop_line  = `#{command_string}`

        # Make Skipping Lines
        command_string = "git show " + revision + ":" + file + " | grep -E -n " \
                                                               "-e \"@{ *" + target_label + " \.\.\.\"" + " " + \
                         "-e \"@} *" + target_label + " \.\.\.\"" + " "
        skip_lines = `#{command_string}`
        start_line = start_line.split(':')[0].to_i
        stop_line  = stop_line.split(':')[0].to_i

        target_line = Array.new()
        if skip_lines != NilClass then
          skip_lines = skip_lines.split("\n").map{|line| line.split(':')[0].to_i}

          target_line = [start_line] + skip_lines + [stop_line]
          target_line = target_line.each_slice(2).to_a
        else
          target_line = [[start_line, stop_line]]
        end

        printf "  TargetLine = %s\n", target_line.to_s

        code_text = ""
        target_line.each_with_index {|line, i|
          command_string = "git show " + revision + ":" + file + " | head -n " + (line[1] - 1).to_s \
                           + " | " + "tail -n +" + (line[0] + 1).to_s + " | grep -v @{ | grep -v @}"
          printf "\nCommand = %s", command_string
          code_text = code_text + `#{command_string}`
          if i != target_line.length-1 then
            code_text = code_text + "...\n"
          end
        }

        out_fp.print "[//]: <> (" + "Revision = " + revision + ", Log = " + commit_log.join(" ") + ", Message = " + target_label + ")\n"
        out_fp.print "- `" + file + "`\n"
        out_fp.print "```" + lang + "\n"
        out_fp.print code_text
        out_fp.print "```\n"
      }
    }
  else
    out_fp.print line
  end
}

# Finally go back to head branch
# Dir.chdir(repo_dir) {
#   command_string = "git checkout myriscvx80_impl"
#   git_log_result = %x[#{command_string}]
# }

out_fp.close
