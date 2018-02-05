# frozen_string_literal: true

require 'date'
require 'erb'
require 'pathname'

# Wrapper for everything
class Gpuzzletime
  def initialize(args)
    @base_url = 'https://time.puzzle.ch'

    @command = (args[0] || :show).to_sym # show, upload
    raise ArgumentError unless %i[show upload].include?(@command)

    @date = named_dates(args[1]) || :all
  end

  def run
    @entries = {}

    parse(read).each do |date, entries|
      # this is mixing preparation, assembly and output, but it gets the job done
      next unless date                             # guard against the machine
      next unless (@date == :all || @date == date) # limit to one day if one is passed
      @entries[date] = []

      start = nil             # at the start of the day, we have no previous end

      entries.each do |entry|
        finish = entry[:time] # we use that twice
        hidden = entry[:description].match(/\*\*$/) # hide lunch and breaks

        if start && !hidden
          case @command # assemble data according to command
          when :show
            @entries[date] << [
              start, '-', finish,
              [entry[:ticket], entry[:description], entry[:tags]].compact.join(' ∴ '),
            ].compact.join(' ')
          when :upload
            @entries[date] << [start, entry]
          end
        end

        start = finish # store previous ending for nice display of next entry
      end
    end

    case @command
    when :show
      @entries.each do |date, entries|
        puts date, '----------'
        entries.each do |entry|
          puts entry
        end
        puts nil
      end
    when :upload
      @entries.each do |date, entries|
        puts "Uploading #{date}"
        entries.each do |start, entry|
          open_browser(start, entry)
        end
      end
    end
  end

  private

  def open_browser(start, entry)
    url = "#{@base_url}/ordertimes/new?#{url_options(start, entry)}"
    system "gnome-open '#{url}'"
  end

  def url_options(start, entry)
    {
      work_date:                    entry[:date],
      'ordertime[ticket]':          entry[:ticket],
      'ordertime[description]':     entry[:description],
      'ordertime[from_start_time]': start,
      'ordertime[to_end_time]':     entry[:time],
      'ordertime[account_id]':      infer_account(entry),
    }
      .map { |key, value| [key, ERB::Util.url_encode(value)].join('=') }
      .join('&')
  end

  def named_dates(date)
    case date
    when 'yesterday'
      Date.today.prev_day.to_s
    when 'today'
      Date.today.to_s
    else
      date
    end
  end

  def read
    Pathname.new('~/.local/share/gtimelog/timelog.txt').expand_path.read
  end

  def parse(data)
    data.split("\n")
        .map { |line| tokenize(line) }
        .group_by { |match| match && match[:date] }
        .to_a
  end

  def tokenize(line)
    re_date = /(?<date>\d{4}-\d{2}-\d{2})/
    re_time = /(?<time>\d{2}:\d{2})/
    re_tick = /(?:(?<ticket>.*?): )/
    re_desc = /(?<description>.*?)/
    re_tags = /(?: -- (?<tags>.*)?)/

    regexp = /^#{re_date} #{re_time}: #{re_tick}?#{re_desc}#{re_tags}?$/
    line.match(regexp)
  end

  def infer_account(entry)
    parser = Pathname.new("~/.config/gpuzzletime/parsers/#{entry[:tags]}")
                     .expand_path

    return unless parser.exist?

    `#{parser} "#{entry[:ticket]}" "#{entry[:description]}"`.chomp
  end
end
