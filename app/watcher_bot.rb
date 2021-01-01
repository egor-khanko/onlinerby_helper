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

text = ''

data.each do |name, price|
  break if price > THRESHOLD

  text << "#{name} at #{price} BYN/TB\n"
end

unless text.empty?
  USERS_TO_SEND.split(',').each do |user_to_send|
    $bot.api.send_message(chat_id: user_to_send.strip, text: text)
  end
end

wait_time = 60 * 60 * 3 # 3 hours
sleep(wait_time)
