#!/usr/bin/env ruby
$stdout.sync = true

require 'bundler/inline'

gemfile do
  source 'https://rubygems.org'

  gem 'nokogiri'
  gem 'httparty'
  gem 'byebug'
  gem 'json'
  gem 'telegram-bot-ruby'
end

require 'telegram/bot'
require_relative 'scraper'
require_relative 'settings_store'

BOT_TOKEN = ENV['BOT_TOKEN']
USERS_TO_SEND = ENV['USERS_TO_SEND']
THRESHOLD = 60

Telegram::Bot::Client.run(BOT_TOKEN) do |bot|
  $bot = bot
end

settings = SettingsStore.new

data = Scraper.new.scrap
selected_data = data.select { |_name, data| data[:price] <= THRESHOLD }

text = ''

unless selected_data.empty?
  concat_prices = selected_data.values.map { |data| data[:price] }.join(',')

  if (settings.read(:last_prices) || '') == concat_prices
    # data the same, just skip
  else
    text << "*New HDD positions:*\n"
    selected_data.each do |name, data|
      text << "[#{name}](#{data[:url]}) at *#{data[:price]}* BYN/TB\n"
    end

    settings.write(:last_prices, concat_prices)
  end
end

unless text.empty?
  USERS_TO_SEND.split(',').each do |user_to_send|
    $bot.api.send_message(chat_id: user_to_send.strip, text: text, parse_mode: :markdown)
  end
end

wait_time = 60 * 60 * 3 # 3 hours
sleep(wait_time)
