#!/usr/bin/env ruby
# Checks every skill: frontmatter that strict YAML parses, a name matching its folder, a description, and no
# person or organisation named, since these skills are shared. Claude Code's own validator tolerates frontmatter
# that YAML rejects, and then silently drops the description.
require "yaml"

NAMES = /daniel|skovli|altinn|digdir/i
root = File.expand_path("..", __dir__)
problems = []

skills = Dir.glob(File.join(root, "skills", "*", "SKILL.md")).sort
problems << "no skills found under skills/" if skills.empty?

skills.each do |path|
  dir = File.basename(File.dirname(path))
  text = File.read(path)
  match = text.match(/\A---\n(.*?)\n---\n/m)
  next problems << "#{dir}: no frontmatter" unless match

  begin
    meta = YAML.safe_load(match[1])
  rescue Psych::SyntaxError => e
    next problems << "#{dir}: frontmatter is not valid YAML (#{e.problem}, line #{e.line})"
  end
  next problems << "#{dir}: frontmatter is not a mapping" unless meta.is_a?(Hash)
  problems << "#{dir}: name is #{meta["name"].inspect}, not #{dir.inspect}" unless meta["name"] == dir
  desc = meta["description"]
  problems << "#{dir}: description missing or empty" unless desc.is_a?(String) && !desc.strip.empty?
end

Dir.glob(File.join(root, "skills", "**", "*")).select { |f| File.file?(f) }.sort.each do |path|
  File.foreach(path).with_index(1) do |line, n|
    problems << "#{path.delete_prefix(root + "/")}:#{n}: names #{line[NAMES]}" if line.scrub =~ NAMES
  end
end

if problems.empty?
  puts "#{skills.size} skills ok"
else
  puts problems
  exit 1
end
