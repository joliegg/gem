# frozen_string_literal: true

require "fileutils"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

namespace :data do
  desc "Refresh data/*.json from a local @joliegg/moderation checkout: rake \"data:sync[/path/to/moderation]\""
  task :sync, [:source] do |_task, args|
    source = args[:source] or abort "usage: rake \"data:sync[/path/to/moderation]\""

    {
      "url-blacklist.json" => "url_blacklist.json",
      "url-shorteners.json" => "url_shorteners.json"
    }.each do |ts_name, ruby_name|
      from = File.join(source, "src", ts_name)
      to = File.expand_path("data/#{ruby_name}", __dir__)
      abort "not found: #{from}" unless File.file?(from)
      FileUtils.cp(from, to)
      puts "synced #{from} -> #{to}"
    end
  end
end

task default: :spec
