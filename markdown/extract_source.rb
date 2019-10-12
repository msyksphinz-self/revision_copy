#!/usr/bin/ruby

text=File.open(ARGV[0]).read
repo_dir = ARGV[1]
out_file = ARGV[2]
out_fp=File.open(out_file, "w")

text.each_line {|line|
  if line =~ /@ref:([^:]*):(.*)$/ then

    lang = $1
    target_string = $2

    command_string = "cd " + repo_dir + " && git log --name-only --oneline -S\"" + target_string + "\""

    git_log_result = `#{command_string}`

    revision = git_log_result.split(" ")[0]
    command_string = "cd " + repo_dir + " && git checkout " + revision
    git_exec_result = `${command_string}`

    git_log_result.split("\n").drop(1).each {|file|
      command_string = "grep -n \"@{" + target_string + "\" " + repo_dir + "/" + file
      start_line = `#{command_string}`
      command_string = "grep -n \"@}" + target_string + "\" " + repo_dir + "/" + file
      stop_line  = `#{command_string}`

      start_line = start_line.split(':')[0].to_i
      stop_line  = stop_line.split(':')[0].to_i

      command_string = "head -n " + (stop_line - 1).to_s + " " + repo_dir + "/" + file \
                       + " | " + "tail -n +" + (start_line + 1).to_s

      code_text = `#{command_string}`

      out_fp.print "[//]: <> (" + "Revision = " + revision + ", File = " + file + ", Message = " + target_string + ")\n"
      out_fp.print "```" + lang + "\n"
      out_fp.print code_text
      out_fp.print "```\n"
    }

  else
    out_fp.print line
  end
}

out_fp.close
