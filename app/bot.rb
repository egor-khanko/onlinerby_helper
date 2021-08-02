$stdout.sync = true

require 'telegram/bot'
require_relative 'settings_store'

class Bot
  attr_reader :bot, :settings, :output_dir, :sleep_time
  USERS_TO_SEND = ENV['USERS_TO_SEND'].split(',').map(&:to_i)

  def initialize()
    @settings = SettingsStore.new
    @curent_temp = {}

    Telegram::Bot::Client.run(ENV['BOT_TOKEN']) do |b|
      @bot = b
    end
  end

  def start
    loop do
      bot.fetch_updates { |message| handle(message) }
    end
  end

  def user_info_markup(user)
    kb = []
    if user[:notifications_enabled]
      kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: "\xE2\x9C\x85 Уведомления включены", callback_data: "disable_notifications")
    else
      kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: "\xE2\x9D\x8C Уведомления выключены", callback_data: "enable_notifications")
    end
    kb << Telegram::Bot::Types::InlineKeyboardButton.new(text: "\xE2\xAC\x87 Изменить порог (текущий: #{user[:threshold]})", callback_data: 'change_threshold')

    Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: kb)
  end

  def clear_context(user)
    @curent_temp[user[:id]] = {}
  end

  def init_context(user)
    @curent_temp[user[:id]] ||= {}
  end

  def add_to_context(user, data)
    @curent_temp[user[:id]] = data
  end

  def get_context(user)
    @curent_temp[user[:id]]
  end

  def handle(message)
    msg = message.is_a?(Telegram::Bot::Types::Message) ? message : message.message

    return respond_empty(msg) unless USERS_TO_SEND.include?(msg.chat.id.to_i)

    user = settings.fetch_user(msg.chat.id.to_i)
    init_context(user)

    case message
    when Telegram::Bot::Types::CallbackQuery
      command = message.data.to_s

      case command
      when 'disable_notifications'
        clear_context(user)
        user = settings.update_user(user, notifications_enabled: false)
        markup = user_info_markup(user)
        bot.api.edit_message_reply_markup(chat_id: message.message.chat.id, message_id: message.message.message_id, reply_markup: markup)
      when 'enable_notifications'
        clear_context(user)
        user = settings.update_user(user, notifications_enabled: true)
        markup = user_info_markup(user)
        bot.api.edit_message_reply_markup(chat_id: message.message.chat.id, message_id: message.message.message_id, reply_markup: markup)
      when 'change_threshold'
        clear_context(user)
        add_to_context(user, change_threshold: true)
        respond(msg, 'Введите новый порог поиска', reply_markup: nil)
      end

    when Telegram::Bot::Types::InlineQuery
      bot.api.answer_inline_query(inline_query_id: message.id, text: '🤷‍♂️')
    when Telegram::Bot::Types::Message
      return if !message.text || message.text.to_s.size == 0

      if message.text == '/start'
        respond(msg, 'Добро пожаловать!', reply_markup: user_info_markup(user))
      elsif message.text == '/tr' || message.text == '/threshold'
        clear_context(user)
        add_to_context(user, change_threshold: true)
        respond(msg, 'Введите новый порог поиска', reply_markup: nil)
      elsif message.text == '/disable'
        clear_context(user)
        user = settings.update_user(user, notifications_enabled: false)
        respond(msg, 'Настройки изменены', reply_markup: user_info_markup(user))
      elsif message.text == '/enable'
        clear_context(user)
        user = settings.update_user(user, notifications_enabled: true)
        respond(msg, 'Настройки изменены', reply_markup: user_info_markup(user))
      elsif get_context(user)[:change_threshold]
        clear_context(user)
        threshold = message.text.strip.tr(',', '.').to_f
        if threshold > 0
          user = settings.update_user(user, threshold: threshold)
          respond(message, "Порог поиска изменен на: #{threshold}", reply_markup: user_info_markup(user))
        else
          respond(message, "Порог поиска должен быть больше нуля: #{threshold}", reply_markup: user_info_markup(user))
        end
      else
        clear_context(user)
        # respond_empty(message)
        respond(message, "Мне нечего ответить на это #{['🤷‍♀️', '🤷‍♂️', '🎅'].sample}, попробуйте выбрать команду из списка", reply_markup: user_info_markup(user))
      end
    end
  end

  def respond_empty(message)
    respond(message, ['🤷‍♀️', '🤷‍♂️', '🎅'].sample)
  end

  def respond(message, text, options = {})
    bot.api.send_message({ chat_id: message.chat.id, text: text}.merge(options))
  end

  def send_image(user, file_path, text)
    bot.api.send_photo(chat_id: user[:id], caption: text, photo: Faraday::UploadIO.new(file_path, ''))
  rescue Telegram::Bot::Exceptions::ResponseError => e
    bot.api.send_message(chat_id: user[:id], text: e.message, parse_mode: :markdown, reply_markup: user_info_markup(user))
  end

  def send_message(user, message)
    bot.api.send_message(chat_id: user[:id], text: message, parse_mode: :markdown, reply_markup: user_info_markup(user))
  rescue Telegram::Bot::Exceptions::ResponseError => e
    err_text = if e.message.include?('message is too long')
                 'Сообщение слишком длинное, попробуйте уменьшить порог'
               else
                 e.message
               end
    bot.api.send_message(chat_id: user[:id], text: err_text, parse_mode: :markdown, reply_markup: user_info_markup(user))
  end
end
