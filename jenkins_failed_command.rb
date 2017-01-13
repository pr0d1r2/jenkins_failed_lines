#!/usr/bin/env ruby

require 'rubygems'
require 'net/http'
require 'nokogiri'
require 'fileutils'

class JenkinsFailedCommand
  attr_accessor :scheme_with_host, :job, :build

  CACHE_STORE = '/tmp/.JenkinsFailedCommand'.freeze
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

    new(scheme_with_host, job, build).failed_command
  end

  def failed_command
    xml.split("Use the following command to run the group again:").last.split("\nTook").first
  end

  private

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
    %W[#{scheme_with_host} job #{job} #{build} consoleText api xml].join('/')
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
  puts JenkinsFailedCommand.from_url(url)
end
