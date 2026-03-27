namespace :coverage do
  desc "Report missing lines and branches from coverage results"
  task :identify_gaps do
    require "json"

    def report_missing(type, dir)
      path = "coverage/#{dir}/.resultset.json"
      unless File.exist?(path)
        puts "No report found for #{type} at #{path}"
        return
      end

      puts "\n--- Missing Coverage: #{type} ---"
      data = JSON.parse(File.read(path))
      data.each do |_command, result|
        result["coverage"].each do |file, coverage|
          missing_lines = coverage["lines"].each_with_index.map { |count, index| count == 0 ? index + 1 : nil }.compact
          puts "  #{file}: lines #{missing_lines.join(', ')}" if missing_lines.any?

          if coverage["branches"]
            coverage["branches"].each do |branch_name, branch_data|
              missing_branches = branch_data.select { |_id, count| count == 0 }.keys
              puts "  #{file}: branch #{branch_name} (#{missing_branches.join(', ')})" if missing_branches.any?
            end
          end
        end
      end
    end

    report_missing("RSpec", "rspec")
    report_missing("Cucumber", "cucumber")
  end
end
