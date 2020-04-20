#!/usr/bin/ruby

text=File.open(ARGV[0]).read
repo_dir = ARGV[1]
out_file = ARGV[2]
out_fp=File.open(out_file, "w")

# Atfirst allowing to write output file

text.each_line {|line|
  if line =~ /@ref:([^:]*):\s*([\w\._\/]+)/ then

    # At first go back to head branch
    # Dir.chdir(repo_dir) {
    #   command_string = "git checkout myriscvx80_impl"
    #   git_log_result = %x[#{command_string}]
    # }

    lang = $1
    target_string = $2

    puts "Found Tag. Language = #{lang}, Message = " + target_string + "\n"

    command_string = "git log --name-only --oneline -n 1 --pickaxe-regex -S\"" + target_string + "$\""

    git_log_result = ""
    Dir.chdir(repo_dir) {
      git_log_result = %x[#{command_string}]
    }

    revision = git_log_result.split(" ")[0]
    # command_string = "git checkout " + revision
    # Dir.chdir(repo_dir) {
    #   git_exec_result = %x[#{command_string}]
    # }

    Dir.chdir(repo_dir) {
      git_log_result.split("\n").drop(1).each {|file|

        command_string = "git show " + revision + ":" + file + " | grep -E -n \"@{ *" + target_string + "$\" "
        puts "Command = " + command_string
        start_line = `#{command_string}`
        command_string = "git show " + revision + ":" + file + " | grep -E -n \"@} *" + target_string + "$\" "
        stop_line  = `#{command_string}`

        # Make Skipping Lines
        command_string = "git show " + revision + ":" + file + " | grep -E -n " \
                                                               "-e \"@{ *" + target_string + " \.\.\.\"" + " " + \
                         "-e \"@} *" + target_string + " \.\.\.\"" + " "
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

        out_fp.print "[//]: <> (" + "Revision = " + revision + ", File = " + file + ", Message = " + target_string + ")\n"
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
