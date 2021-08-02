#!/usr/bin/env ruby
$stdout.sync = true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'nokogiri'
  gem 'httparty'
  gem 'pry-byebug'
  gem 'json'
  gem 'geckodriver-helper'
  gem 'selenium-webdriver'
  gem 'watir-screenshot-stitch'
  gem 'telegram-bot-ruby'
end

require 'telegram/bot'
require 'watir-screenshot-stitch'
require 'pry'
require_relative 'scraper'
require_relative 'bot'
require_relative 'settings_store'

BOT_TOKEN = ENV['BOT_TOKEN']
USERS_TO_SEND = ENV['USERS_TO_SEND']

SEND_IMAGES = ENV['SEND_IMAGES'] || false
BASE_DIR = '/usr/app'

Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
  $bot = bot
end

def download_image(url)
  path = File.join(BASE_DIR, 'image.png')

  b = Watir::Browser.new(:firefox, timeout: 120, url: 'http://selenium:4444/wd/hub')
  b.goto(url)

  File.delete(path) if File.exist?(path)

  sleep(3)
  # https://github.com/samnissen/watir-screenshot-stitch
  png = b.screenshot.base64_geckodriver

  File.open(path, 'wb') { |f| f.write(Base64.decode64(png)) }

  sleep(0.5)

  true
rescue StandardError => e
  puts "failed to download with: #{e.message}"
  false
end

bot = Bot.new

bot_thread = Thread.new do
  puts 'bot is running...'
  loop do
    begin
      bot.start
    rescue Exception => e
      puts e.message
      puts e.backtrace
      puts "something went wrong in bot thread, should be restarted"
    end
  end
end


watcher_thread = Thread.new do
  loop do
    raw_data = Scraper.new.scrap

    settings = SettingsStore.new

    users = settings.read(:users) || []

    users.each do |user_id, user_data|
      next if user_data[:notifications_enabled] == false

      # threshold = (user_data[:threshold] ||= settings.default_threshold).to_f
      threshold = user_data[:threshold]

      selected_data = raw_data.select { |_name, data| data[:value] <= threshold }

      next if selected_data.empty?

      concat_prices = selected_data.values.map { |data| data[:value] }.join(',')

      if (user_data[:last_prices] || '') == concat_prices
        # data the same, just skip
      else
        if SEND_IMAGES
          send_text("======= *#{Time.now.strftime('%Y.%m.%d %H:%M')}* =========")
          selected_data.each do |name, data|
            if download_image(data[:url])
              text = "#{name} - #{data[:url]} at #{data[:value]} BYN/TB (#{data[:price]}BYN)\n"

              file_path = File.join(BASE_DIR, 'image.png')
              bot.send_image(user_data, file_path, text)
            else
              fixed_name = name.tr('[', '{').tr(']', '}')
              text = "[#{fixed_name}](#{data[:url]}) at *#{data[:value]}* BYN/TB (#{data[:price]}BYN)\n"
              bot.send_message(user_data, text)
            end
          end
        else
          all_text = ["======= *#{Time.now.strftime('%Y.%m.%d %H:%M')}* ========="]
          selected_data.each do |name, data|
            fixed_name = name.tr('[', '{').tr(']', '}')
            all_text << "[#{fixed_name}](#{data[:url]}) at *#{data[:value]}* BYN/TB (#{data[:price]}BYN)"
          end

          bot.send_message(user_data, all_text.join("\n"))
          # without images, one list
        end

        user_data[:last_prices] = concat_prices
        settings.update_user(user_data)
      end
    end

    wait_time = 60 * 60 * 1.5 # 1.5 hours
    sleep(wait_time)
  end
end

[bot_thread, watcher_thread].each(&:join)
