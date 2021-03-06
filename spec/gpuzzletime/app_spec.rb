# frozen_string_literal: true

require 'spec_helper'

describe Gpuzzletime::App do
  subject { described_class.new([command, argument].compact) }

  let(:command) { 'show' }
  let(:argument) { 'all' }
  let(:timelog) do
    Gpuzzletime::Timelog.new.parse <<~TIMELOG
      2018-03-02 09:51: start **
      2018-03-02 11:40: 12345: prepare deployment -- webapp
      2018-03-02 12:25: lunch **
      2018-03-02 13:15: 12345: prepare deployment -- webapp
      2018-03-02 14:30: break **
      2018-03-02 16:00: handover
      2018-03-02 17:18: cleanup database
      2018-03-02 18:58: break **
      2018-03-02 20:08: 12345: prepare deployment -- webapp

      2018-03-03 14:00: start **
      2018-03-03 15:34: 23456: debug -- network
      2018-03-03 18:46: studying
      2018-03-03 20:08: dinner **
      2018-03-03 21:36: 12345: prepare deployment -- webapp

      2018-03-05 09:00: start **
    TIMELOG
  end

  # xit 'has a configurable puzzletime-domain'

  it 'omits entries ending in two stars' do
    expect(subject).to receive(:timelog).at_least(:once).and_return(timelog)

    expect { subject.run }.to output(/studying/).to_stdout
    expect { subject.run }.not_to output(/dinner/).to_stdout
    expect { subject.run }.not_to output(/lunch/).to_stdout
    expect { subject.run }.not_to output(/break/).to_stdout
  end

  it 'knows today by name' do
    today = '2018-03-03'

    Timecop.travel(today) do
      expect(subject.send(:named_dates, 'today')).to eq(today)
    end
  end

  it 'knows yesterday by name' do
    today     = '2018-03-03'
    yesterday = '2018-03-02'

    Timecop.travel(today) do
      expect(subject.send(:named_dates, 'yesterday')).to eq(yesterday)
    end
  end

  it 'knows the last day by name' do
    expect(subject).to receive(:timelog).at_least(:once).and_return(timelog)
    last_day = '2018-03-03' # dependent on test-data of timelog above

    expect(subject.send(:named_dates, 'last')).to eq(last_day)
  end

  it 'understands and accepts dates in YYYY-MM-DD format' do
    date = '1970-01-01'
    expect(subject.send(:named_dates, date)).to be date
  end
  # it 'defaults to "last day"'

  # it 'can show parsed entries'
  # it 'can upload parsed entries'
  # it 'omits empty dates'
  # it 'can limit entries to one day'

  # it 'can load custom mappers for the ordertime_account'

  # it 'can open the timelog in an editor'
  # it 'can open a parser-script in an editor'
end
