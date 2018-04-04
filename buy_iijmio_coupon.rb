# coding: utf-8
require 'yaml'
require 'logger'
require 'optparse'
require 'capybara'
require 'capybara/dsl'
require 'selenium-webdriver'
require 'socket'

class BuyIIJmioCoupon
  include Capybara::DSL

  CHROME = 0
  HEADLESS_CHROME = 1

  def initialize(driver, logger = nil)
    @logger = logger || Logger.new(STDERR)
    Capybara.app_host = 'https://www.iijmio.jp/service/setup/hdd/charge/'
    Capybara.default_max_wait_time = 5
    Capybara.current_driver = :selenium
    Capybara.javascript_driver = :selenium

    capabilities =
      case driver
      when CHROME
        Selenium::WebDriver::Remote::Capabilities.chrome(
          chromeOptions: { args: %w() }
        )

      when HEADLESS_CHROME
        Selenium::WebDriver::Remote::Capabilities.chrome(
          chromeOptions: { args: %w(headless disable-gpu) }
        )
      end

    Capybara.register_driver :selenium do |app|
      Capybara::Selenium::Driver.new(
        app,
        browser: :chrome,
        desired_capabilities: capabilities
      )
    end
  end

  attr_reader :logger

  def login
    visit('')
    login_info = YAML.load_file('./config.yml')['login_info']
    fill_in 'j_username',
      :with => login_info['username']
    fill_in 'j_password',
      :with => login_info['password']
    click_button 'ログイン'
  end

  def buy
    select '1枚（100MB）', from: 'selectList'
    click_button '次へ'

    check 'confirm'
    click_button 'お申し込み'
  end

  def dump
    @logger.error page.html
  end
end

params = ARGV.getopts('', 'debug')

if params['debug']
  begin
    logger = Logger.new('log')
    crawler = BuyIIJmioCoupon.new(BuyIIJmioCoupon::CHROME, logger)
    crawler.login
    crawler.buy
    exit
  rescue
    crawler.dump
    raise
  end
end

gs = TCPServer.open(23456)
addr = gs.addr
addr.shift
printf("server is on %s\n", addr.join(":"))

crawler = BuyIIJmioCoupon.new(BuyIIJmioCoupon::HEADLESS_CHROME)
loop do
  s = gs.accept
  print(s, " is accepted\n")

  begin
    crawler.login
    crawler.buy
  rescue
    raise
  end

  print(s, " is gone\n")
  s.close
end
