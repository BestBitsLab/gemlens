# frozen_string_literal: true

require "date"
require "json"
require "open3"
require "colorize"
require "yaml"

module Gemlens
  GEMS_YML_PATH = File.expand_path("../../data/gems.yml", __dir__)
  GEMS_YML = File.exist?(GEMS_YML_PATH) ? YAML.load_file(GEMS_YML_PATH) : []

  GEM_TO_REPOS = GEMS_YML.each_with_object({}) do |entry, hash|
    hash[entry["full_name"]] = entry["repos"] || []
  end

  class GemfileHistoryAnalyzer
    def initialize(repo_path = ".")
      @repo_path = repo_path
    end

    def analyze
      return not_enough_history if gemfile_commits.size < 2

      history = Hash.new { |h, k| h[k] = [] }

      gemfile_commits.reverse.each_cons(2) do |older, newer|
        before = parse_gemfile_at(older[:sha])
        after  = parse_gemfile_at(newer[:sha])

        process_changes(before, after, newer, history)
      end

      history
    end

    def not_enough_history
      puts "📘 Only one commit related to Gemfile found. Not enough history to analyze changes.".colorize(:light_blue)
      {}
    end

    def process_changes(before, after, commit, history)
      added   = after.keys - before.keys
      removed = before.keys - after.keys
      common  = before.keys & after.keys

      handle_added(added, after, commit, history)
      handle_removed(removed, before, commit, history)
      handle_updated(common, before, after, removed, commit, history)
    end

    def handle_added(added, after, commit, history)
      added.each do |gem_name|
        history[gem_name] << build_event(
          "added", gem_name,
          commit.merge(version: after[gem_name])
        )
      end
    end

    def handle_removed(removed, before, commit, history)
      removed.each do |gem_name|
        history[gem_name] << build_event(
          "removed", gem_name,
          commit.merge(version: before[gem_name])
        )
      end
    end

    def handle_updated(common, before, after, removed, commit, history)
      updated = common.select do |gem_name|
        before[gem_name] != after[gem_name] && !removed.include?(gem_name)
      end

      updated.each do |gem_name|
        history[gem_name] << build_event(
          "updated", gem_name,
          commit.merge(
            version_from: before[gem_name],
            version_to: after[gem_name]
          )
        )
      end
    end

    def gemfile_commits
      return [] unless valid_git_repo?

      Dir.chdir(@repo_path) do
        parse_git_log(`git log --follow --format="%H|%an|%ad|%s" --date=iso Gemfile`)
      end
    end

    def valid_git_repo?
      Dir.chdir(@repo_path) do
        system("git rev-parse HEAD > /dev/null 2>&1") || begin
          puts "⚠️  No commits found in the repository yet.".colorize(:yellow)
          false
        end
      end
    end

    def parse_git_log(log_output)
      log_output.lines.map do |line|
        sha, author, date, message = line.strip.split("|", 4)
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

    def parse_gemfile_at(commit_sha)
      content = Dir.chdir(@repo_path) do
        `git show #{commit_sha}:Gemfile`
      end

      gems = {}
      content.each_line do |line|
        next unless (match = line.match(/^\s*gem\s+["'](?<name>[^"']+)["'](?:\s*,\s*["'](?<version>[^"']+)["'])?/))

        name = match[:name]
        version = match[:version]
        gems[name] = version
      end
      gems
    end

    def build_event(action, _gem_name, commit)
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

  def self.flatten_and_sort(history)
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
    end

    flattened.sort_by { |e| e[:date] }
  end

  def self.format_event_line(event)
    [
      color_tag(event[:action]),
      event[:date].strftime("%Y-%m-%d"),
      format_label(event),
      format_gem(event),
      "by #{event[:author].ljust(10)}",
      "➜ #{format_pr(event)}",
      "| #{event[:message]}"
    ].join(" ").strip
  end

  def self.format_label(event)
    event[:action].capitalize.ljust(8)
  end

  def self.format_gem(event)
    version_str = format_version(event)
    text = (event[:gem] + version_str).ljust(20)
    colorize_by_action(text, event[:action])
  end

  def self.format_version(event)
    if event[:action] == "updated" && event[:version_from] && event[:version_to]
      " (#{event[:version_from]} → #{event[:version_to]})"
    elsif event[:version]
      " (#{event[:version]})"
    else
      ""
    end
  end

  def self.colorize_by_action(text, action)
    case action
    when "added"   then text.colorize(:green)
    when "removed" then text.colorize(:red)
    when "updated" then text.colorize(:blue)
    else text
    end
  end

  def self.format_pr(event)
    if event[:pr]
      "PR ##{event[:pr].rjust(4)}"
    elsif event[:sha]
      event[:sha][0..6]
    else
      "—"
    end
  end

  def self.print_timeline(history)
    puts "\n📜 Gemfile History Timeline\n\n"
    flatten_and_sort(history).each do |e|
      puts format_event_line(e)
    end
  end

  def self.run(repo_path = ".")
    history = GemfileHistoryAnalyzer.new(repo_path).analyze
    return if history.empty?

    print_timeline(history)

    # Collect recently added gems
    added_gems = history.select { |_gem, events| events.any? { |e| e[:action] == "added" } }.keys
    return if added_gems.empty?

    puts "\n🔗 See all popular projects using the same gems as you:"
    added_gems.uniq.each do |gem_name|
      puts "  🌐 https://www.outrelax.com/gems/#{gem_name}"
    end
  end
end
