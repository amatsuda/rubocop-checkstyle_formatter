# encoding: utf-8

require 'spec_helper'
require 'rubocop/rspec/cop_helper'
require 'stringio'
require 'rexml/document'

module RuboCop
  module Formatter
    describe CheckstyleFormatter do
      include CopHelper

      let(:severities) { %i[refactor convention warning error fatal] }
      let(:cop) do
        Cop::Cop.new.tap do |c|
          processed_source = RuboCop::ProcessedSource.new(file, 2.7, 'sample.rb')
          if RuboCop::Version.version >= '1.40.0'
            processed_source.registry = registry
          end
          c.send(:begin_investigation, processed_source)
          source_buffer = Parser::Source::Buffer.new('sample.rb', 1).tap { |b| b.source = '' }
          severities.each_with_index do |severity, index|
            range = Parser::Source::Range.new(source_buffer, 0, index)
            c.add_offense(processed_source.ast, location: range, message: severity.to_s)
          end
        end
      end
      let(:output) { StringIO.new }
      let(:file) { File.join(Dir.pwd, 'sample.rb') }

      before do
        formatter = described_class.new(output)
        formatter.started(file)
        formatter.file_finished(file, cop.respond_to?(:offenses) ? cop.offenses : cop.offences)
        formatter.finished([file])
      end

      it 'should convert rubocop severity to checkstyle severity' do
        doc = REXML::Document.new(output.string)
        REXML::XPath.match(doc, '/checkstyle/file').each do |file|
          if defined?(PathUtil)
            expect(file.attribute('name').value).to eq('sample.rb')
          end
          REXML::XPath.match(file, '/error').each do |error|
            message = error.attribute('message').value
            severity = error.attribute('severity').value
            case message
            when 'refactor', 'convention' then expect(severity).to eq('info')
            when 'warning' then expect(severity).to eq('warning')
            when 'error', 'fatal' then expect(severity).to eq('error')
            end
          end
        end
      end

      context 'RUBOCOP_CHECKSTYLE_FORMATTER_ABSOLUTE_PATH is defined' do
        around do |example|
          ENV['RUBOCOP_CHECKSTYLE_FORMATTER_ABSOLUTE_PATH'] = 'true'
          example.run
          ENV.delete('RUBOCOP_CHECKSTYLE_FORMATTER_ABSOLUTE_PATH')
        end

        it 'should use absolute path in name attribute of file tag' do
          output = StringIO.new
          formatter = described_class.new(output)
          formatter.started(file)
          formatter.file_finished(file, cop.respond_to?(:offenses) ? cop.offenses : cop.offences)
          formatter.finished([file])
          doc = REXML::Document.new(output.string)
          file = REXML::XPath.first(doc, '/checkstyle/file')
          expect(Pathname.new(file.attributes['name'])).to be_absolute
        end
      end
    end
  end
end
