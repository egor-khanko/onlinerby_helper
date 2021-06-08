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
require_relative 'settings_store'

BOT_TOKEN = ENV['BOT_TOKEN']
USERS_TO_SEND = ENV['USERS_TO_SEND']

THRESHOLD = ENV['THRESHOLD'].to_f
SEND_IMAGES = ENV['SEND_IMAGES'] || false
THRESHOLD = 60 if THRESHOLD.zero?
BASE_DIR = '/usr/app'

Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
  $bot = bot
end

settings = SettingsStore.new

selected_data = Scraper.new.scrap.select { |_name, data| data[:value] <= THRESHOLD }

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

def send_image(text)
  USERS_TO_SEND.split(',').each do |user_to_send|
    file_path = File.join(BASE_DIR, 'image.png')
    begin
      $bot.api.send_photo(chat_id: user_to_send.strip, caption: text, photo: Faraday::UploadIO.new(file_path, ''))
    rescue Telegram::Bot::Exceptions::ResponseError => e
      puts "Failed to upload file #{file_path} as photo"
    end
  end
end

def send_text(text)
  USERS_TO_SEND.split(',').each do |user_to_send|
    $bot.api.send_message(chat_id: user_to_send.strip, text: text, parse_mode: :markdown)
  end
end

unless selected_data.empty?
  concat_prices = selected_data.values.map { |data| data[:value] }.join(',')

  if (settings.read(:last_prices) || '') == concat_prices
    # data the same, just skip
  else
    if SEND_IMAGES
      send_text("======= *#{Time.now.strftime('%Y.%m.%d %H:%M')}* =========")
      selected_data.each do |name, data|
        if download_image(data[:url])
          text = "#{name} - #{data[:url]} at #{data[:value]} BYN/TB (#{data[:price]}BYN)"
          send_image(text)
        else
          fixed_name = name.tr('[', '{').tr(']', '}')
          text = "[#{fixed_name}](#{data[:url]}) at *#{data[:value]}* BYN/TB (#{data[:price]}BYN)"
          send_text(text)
        end
      end
    else
      all_text = ["======= *#{Time.now.strftime('%Y.%m.%d %H:%M')}* ========="]
      selected_data.each do |name, data|
        fixed_name = name.tr('[', '{').tr(']', '}')
        all_text << "[#{fixed_name}](#{data[:url]}) at *#{data[:value]}* BYN/TB (#{data[:price]}BYN)"
      end

      send_text(all_text.join("\n"))
      # without images, one list
    end

    settings.write(:last_prices, concat_prices)
  end
end

wait_time = 60 * 60 * 1.5 # 1.5 hours
sleep(wait_time)
