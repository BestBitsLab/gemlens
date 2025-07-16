require "date"
require "json"
require "open3"
require "colorize"
require "yaml"

module Gemlens
  GEMS_YML_PATH = File.expand_path("../../../data/gems.yml", __FILE__)
  GEMS_YML = File.exist?(GEMS_YML_PATH) ? YAML.load_file(GEMS_YML_PATH) : []

  GEM_TO_REPOS = GEMS_YML.each_with_object({}) do |entry, hash|
    hash[entry["full_name"]] = entry["repos"] || []
  end

  class GemfileHistoryAnalyzer
    def initialize(repo_path = ".")
      @repo_path = repo_path
    end

    def gemfile_commits
      Dir.chdir(@repo_path) do
        unless system("git rev-parse HEAD > /dev/null 2>&1")
          puts "⚠️  No commits found in the repository yet.".colorize(:yellow)
          return []
        end

        `git log --follow --format="%H|%an|%ad|%s" --date=iso Gemfile`.lines.map do |line|
          sha, author, date, message = line.strip.split("|", 4)

          # Extract PR number if present
          pr = message[/(?:#|PR\s*)(\d+)/i, 1]

          {
            sha: sha,
            author: author,
            date: DateTime.parse(date),
            message: message.strip,
            pr: pr
          }
        end
      end
    end

    def parse_gemfile_at(commit_sha)
      content = Dir.chdir(@repo_path) do
        `git show #{commit_sha}:Gemfile`
      end

      gems = {}
      content.each_line do |line|
        if line =~ /^\s*gem\s+["']([^"']+)["'](?:\s*,\s*["']([^"']+)["'])?/
          name = $1
          version = $2
          gems[name] = version
        end
      end
      gems
    end

    def analyze
      history = Hash.new { |h, k| h[k] = [] }

      if gemfile_commits.size < 2
        puts "📘 Only one commit related to Gemfile found. Not enough history to analyze changes.".colorize(:light_blue)
        return history
      end

      gemfile_commits.reverse.each_cons(2) do |older, newer|
        before = parse_gemfile_at(older[:sha])
        after  = parse_gemfile_at(newer[:sha])

        added   = after.keys - before.keys
        removed = before.keys - after.keys
        common  = before.keys & after.keys

        added.each do |gem_name|
          history[gem_name] << build_event("added", gem_name, newer.merge(version: after[gem_name]))
        end

        # Only gems that exist in both and changed version count as updated
        updated = common.select do |gem_name|
          before[gem_name] != after[gem_name]
        end

        removed.each do |gem_name|
          history[gem_name] << build_event("removed", gem_name, newer.merge(
            version: before[gem_name]
          ))
        end

        updated -= removed

        updated.each do |gem_name|
          history[gem_name] << build_event("updated", gem_name, newer.merge(
            version_from: before[gem_name],
            version_to:   after[gem_name]
          ))
        end
      end

      history
    end

    def build_event(action, gem_name, commit)
      {
        action: action,
        by: commit[:author],
        at: commit[:date].to_s,
        message: commit[:message],
        pr: commit[:pr],
        sha: commit[:sha],
        version: commit[:version],
        version_from: commit[:version_from], # only present on update
        version_to: commit[:version_to]      # only present on update
      }
    end
  end

  def self.color_tag(action)
    case action
    when "added"   then "🟩".colorize(:green)
    when "removed" then "🟥".colorize(:red)
    when "updated" then "🟦".colorize(:blue)
    else "⬜".colorize(:light_black)
    end
  end

  def self.print_timeline(history)
    puts "\n📜 Gemfile History Timeline\n\n"
    flattened = history.flat_map do |gem, events|
      events.map do |e|
        {
          date: DateTime.parse(e[:at]),
          at: e[:at],
          action: e[:action],
          gem: gem,
          author: e[:by],
          message: e[:message],
          pr: e[:pr],
          sha: e[:sha],
          version: e[:version],
          version_from: e[:version_from],
          version_to: e[:version_to],
          repo: e[:repo]
        }
      end
    end.sort_by { |e| e[:date] }

    flattened.each do |e|
      label = e[:action].capitalize.ljust(8)

      version_str =
        if e[:action] == "updated" && e[:version_from] && e[:version_to]
          " (#{e[:version_from]} → #{e[:version_to]})"
        elsif e[:version]
          " (#{e[:version]})"
        else
          ""
        end

      gem_label = case e[:action]
                  when "added"   then (e[:gem] + version_str).ljust(20).colorize(:green)
                  when "removed" then (e[:gem] + version_str).ljust(20).colorize(:red)
                  when "updated" then (e[:gem] + version_str).ljust(20).colorize(:blue)
                  else                (e[:gem] + version_str).ljust(20)
                  end

      pr_info = if e[:pr]
                  "PR ##{e[:pr].rjust(4)}"
                elsif e[:sha]
                  e[:sha][0..6]
                else
                  "—"
                end

      puts "#{color_tag(e[:action])} #{e[:date].strftime('%Y-%m-%d')}  " \
           "#{label} #{gem_label} by #{e[:author].ljust(10)} ➜ #{pr_info} | #{e[:message]}"
    end
  end

  def self.run(repo_path = ".")
    history = GemfileHistoryAnalyzer.new(repo_path).analyze
    print_timeline(history) unless history.empty?
  end
end
