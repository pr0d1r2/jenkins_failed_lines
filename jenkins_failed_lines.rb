#!/usr/bin/env ruby

require 'rubygems'
require 'net/http'
require 'nokogiri'
require 'fileutils'

class JenkinsFailedLines
  attr_accessor :scheme_with_host, :job, :build

  CACHE_STORE = '/tmp/.JenkinsFailedLines'.freeze
  UNAUTHORIZED_STRINGS = [
    'Server returned HTTP response code: 401'
  ].freeze

  def initialize(scheme_with_host, job, build)
    @scheme_with_host = scheme_with_host
    @job = job
    @build = build
  end

  def self.from_url(url)
    scheme_with_host = url.split('/').slice(0..2).join('/')
    job = url.split('/').slice(4)
    build = url.split('/').slice(5).to_i

    new(scheme_with_host, job, build).failed_lines
  end

  def failed_lines
    if cucumber?
      if child_reports.any?
        failed_cucumber_lines_from_child_reports
      else
        failed_cucumber_lines_from_stack_traces
      end
    else
      failed_rspec_lines
    end
  end

  private

  def cucumber?
    job.include?('-features')
  end

  def failed_rspec_lines
    check_authorized!
    stack_traces.map do |stack_trace|
      begin
        stack_trace
          .text
          .split("\n")
          .detect { |line| line =~ /spec\.rb:/ && !line.include?('# ./') }
          .split(':')
          .slice(0..1)
          .join(':')
      rescue NoMethodError
      end
    end.compact.uniq
  end

  def stack_traces
    xml_doc.xpath('//errorStackTrace')
  end

  def failed_cucumber_lines_from_stack_traces
    check_authorized!
    stack_traces.map do |stack_trace|
      begin
        stack_trace
          .text
          .split("\n")
          .detect { |line| line =~ /\.feature/ }
          .split(':')
          .slice(0..1)
          .join(':')
      rescue NoMethodError
      end
    end.compact.uniq
  end

  def failed_cucumber_lines_from_child_reports
    check_authorized!
    failed_child_report_urls.map do |failed_child_report_url|
      content = cache(failed_child_report_url.gsub(/[^0-9A-Za-z]/i, '_')) do
        fetch(failed_child_report_url)
      end
      Nokogiri::HTML(content).xpath('//pre').map(&:text).map do |text|
        text.split("\n").detect { |line| line =~ /^feature/ }
      end.compact.first.split(':').slice(0..1).join(':')
    end.uniq
  end

  def check_authorized!
    return true unless UNAUTHORIZED_STRINGS.detect { |string| xml.include?(string) }
    FileUtils.rm_f(cache_path)
    fail ArgumentError, 'Unauthorized, you probably did not set JENKINS_LOGIN and JENKINS_TOKEN env variables, removing cache ...'
  end

  def failed_child_report_urls
    failed_child_reports.map do |failed_child_report|
      failed_cases = failed_child_report.xpath('result/suite/case').select do |the_case|
        the_case.xpath('status').text == 'FAILED'
      end
      report_url = failed_child_report.xpath('child/url').text
      failed_cases.map do |failed_case|
        "#{report_url}testReport/(root)/#{URI.escape(failed_case.xpath('className').text)}/#{failed_case.xpath('name').text.gsub(/[^0-9A-Za-z]/i, '_')}/"
      end
    end.flatten
  end

  def failed_child_reports
    child_reports.select do |report|
      report.xpath('result/failCount').text.to_i > 0
    end
  end

  def child_reports
    @child_reports ||= xml_doc.xpath('//childReport')
  end


  def xml_doc
    @xml_doc ||= Nokogiri::XML(xml)
  end

  def xml
    @xml ||= cache do
      fetch(request_url)
    end
  end

  def fetch(url)
    uri = URI(url)

    req = Net::HTTP::Post.new(uri)
    req.basic_auth JENKINS_LOGIN, JENKINS_TOKEN

    res = Net::HTTP.start(uri.hostname, uri.port, use_ssl: uri.scheme == 'https') do |http|
      http.request(req)
    end

    res.body
  end

  def request_url
    %W[#{scheme_with_host} job #{job} #{build} testReport api xml].join('/')
  end

  def cache(report = nil)
    FileUtils.mkdir_p(CACHE_STORE) unless File.directory?(CACHE_STORE)
    if File.exists?(cache_path(report))
      File.read(cache_path(report))
    else
      content = Proc.new { yield }.call
      File.write(cache_path(report), content)
      content
    end
  end

  def cache_path(report = nil)
    [CACHE_STORE, cache_file(report)].join('/')
  end

  def cache_file(report = nil)
    [job, build, report].compact.join('-')
  end
end

JENKINS_LOGIN = ENV['JENKINS_LOGIN'].freeze
JENKINS_TOKEN = ENV['JENKINS_TOKEN'].freeze

ARGV.each do |url|
  puts JenkinsFailedLines.from_url(url)
end
