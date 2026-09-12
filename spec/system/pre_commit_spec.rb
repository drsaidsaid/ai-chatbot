require 'spec_helper'
require 'tmpdir'
require 'fileutils'
require 'open3'
require 'json'

RSpec.describe 'Pre-commit staged-file checks' do
  let(:repository) { File.expand_path('../..', __dir__) }
  let(:paths) { ['lib/ordinary.rb', 'lib/space name.rb', "lib/#{'nested/' * 22}long name.rb", "lib/line\nbreak.rb"] }

  def git(directory, *)
    output, status = Open3.capture2e('git', *, chdir: directory)
    raise output unless status.success?

    output
  end

  def install_hook(directory)
    FileUtils.mkdir_p(File.join(directory, '.husky/_'))
    FileUtils.cp(File.join(repository, '.husky/pre-commit'), File.join(directory, '.husky/pre-commit'))
    FileUtils.cp(File.join(repository, '.husky/_/husky.sh'), File.join(directory, '.husky/_/husky.sh'))
  end

  def write_linter(directory)
    File.write(File.join(directory, 'fake-bin/bundle'), <<~SCRIPT)
      #!/usr/bin/env ruby
      require 'json'
      separator = ARGV.index('--')
      options = separator ? ARGV[2...separator] : ARGV.drop(2).take_while { |argument| argument.start_with?('-') }
      paths = separator ? ARGV.drop(separator + 1) : ARGV.drop(2 + options.length)
      abort 'Unexpected linter command' unless ARGV.first(2) == ['exec', 'rubocop']
      abort 'Unexpected linter options' unless options == ['--force-exclusion', '-a']
      File.open(ENV.fetch('HOOK_CALLS'), 'a') do |file|
        file.puts(JSON.generate('options' => options, 'paths' => paths, 'terminated' => !separator.nil?))
      end
      paths.each { |path| File.open(path, 'a') { |file| file.puts('# formatted') } }
      exit Integer(ENV.fetch('FAKE_RUBOCOP_EXIT', '0'))
    SCRIPT
  end

  def prepare_scratch(directory)
    git(directory, 'init', '--quiet')
    install_hook(directory)
    FileUtils.mkdir_p(File.join(directory, 'fake-bin'))
    File.write(File.join(directory, 'fake-bin/npx'), "#!/bin/sh\nexit \"${FAKE_NPX_EXIT:-0}\"\n")
    write_linter(directory)
    FileUtils.chmod('+x', Dir[File.join(directory, 'fake-bin/*')])
    [*paths, 'docs/evidence.rb.txt', 'lib/not_staged.rb'].each do |path|
      FileUtils.mkdir_p(File.dirname(File.join(directory, path)))
      File.write(File.join(directory, path), "# original\n")
    end
    git(directory, 'add', '--', *paths, 'docs/evidence.rb.txt')
  end

  def run_hook(directory, **overrides)
    environment = { 'PATH' => "#{directory}/fake-bin:#{ENV.fetch('PATH')}", 'HOOK_CALLS' => "#{directory}/calls.jsonl",
                    'HUSKY' => nil, 'HUSKY_SKIP_HOOKS' => nil, 'husky_skip_init' => nil }.merge(overrides.transform_keys(&:to_s))
    Open3.capture2e(environment, 'sh', '.husky/pre-commit', chdir: directory)
  end

  def checked_paths(directory)
    log = File.join(directory, 'calls.jsonl')
    File.exist?(log) ? File.readlines(log).flat_map { |line| JSON.parse(line).fetch('paths') } : []
  end

  it 'checks and stages every eligible path including spaces, newlines and long paths' do
    Dir.mktmpdir('r09-hook-') do |directory|
      prepare_scratch(directory)
      output, status = run_hook(directory)

      expect(status.success?).to be(true), output
      expect(checked_paths(directory)).to match_array(paths), output
      expect(git(directory, 'diff', '--name-only')).to eq('')
      expect(File.read(File.join(directory, 'docs/evidence.rb.txt'))).to eq("# original\n")
      expect(File.read(File.join(directory, 'lib/not_staged.rb'))).to eq("# original\n")
    end
  end

  it 'reports a Ruby check failure while checking every eligible staged path' do
    Dir.mktmpdir('r09-hook-') do |directory|
      prepare_scratch(directory)
      output, status = run_hook(directory, FAKE_RUBOCOP_EXIT: '1')

      expect(status.success?).to be(false), output
      expect(checked_paths(directory)).to match_array(paths)
    end
  end

  it 'reports a staging failure after checking every eligible path' do
    Dir.mktmpdir('r09-hook-') do |directory|
      prepare_scratch(directory)
      File.write(File.join(directory, '.git/index.lock'), '')
      output, status = run_hook(directory)

      expect(status.success?).to be(false), output
      expect(checked_paths(directory)).to match_array(paths)
    end
  end

  it 'reports failure to enumerate staged files before invoking Ruby checks' do
    Dir.mktmpdir('r09-hook-') do |directory|
      prepare_scratch(directory)
      FileUtils.mv(File.join(directory, '.git'), File.join(directory, 'saved-git'))
      output, status = run_hook(directory)

      expect(status.success?).to be(false), output
      expect(checked_paths(directory)).to be_empty
    end
  end

  it 'preserves lint-staged failure propagation without invoking Ruby checks' do
    Dir.mktmpdir('r09-hook-') do |directory|
      prepare_scratch(directory)
      output, status = run_hook(directory, FAKE_NPX_EXIT: '2')

      expect(status.success?).to be(false), output
      expect(checked_paths(directory)).to be_empty
    end
  end

  it 'ignores staged paths whose files no longer exist' do
    Dir.mktmpdir('r09-hook-') do |directory|
      prepare_scratch(directory)
      File.delete(File.join(directory, paths.first))
      output, status = run_hook(directory)

      expect(status.success?).to be(true), output
      expect(checked_paths(directory)).to match_array(paths.drop(1))
    end
  end

  context 'with an option-like root filename' do
    let(:paths) { super() + ['--require=payload.rb'] }

    it 'passes the name as a pathname without adding linter options' do
      Dir.mktmpdir('r09-hook-') do |directory|
        prepare_scratch(directory)
        output, status = run_hook(directory)

        expect(status.success?).to be(true), output
        expect(checked_paths(directory)).to match_array(paths)
        expect(git(directory, 'diff', '--name-only')).to eq('')
      end
    end
  end
end
