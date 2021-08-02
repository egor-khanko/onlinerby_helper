require 'yaml/store'

class SettingsStore
  DEFAULT_THRESHOLD = ENV['THRESHOLD'].to_f
  DEFAULT_THRESHOLD = 80 if DEFAULT_THRESHOLD.zero?

  attr_reader :store
  def initialize
    @store = YAML::Store.new('db_settings.yml')
  end

  def write(which, data)
    store.transaction do
      store[which] = data

      store.commit
    end
  end

  def default_threshold
    DEFAULT_THRESHOLD
  end

  def read(which)
    store.transaction { store[which] }
  end

  def fetch_user(user_id)
    (read(:users) || {})[user_id] || default_user_data(user_id)
  end

  def default_user_data(user_id)
    { id: user_id, threshold: default_threshold }
  end

  def update_user(data, new_data = data)
    user_id = data[:id]
    data_to_return = nil
    store.transaction do
      users = store[:users] || {}
      users[user_id] ||= default_user_data(user_id)

      data_to_return = users[user_id].merge!(new_data)
      store[:users] = users

      store.commit
    end
    data_to_return
  end
end
