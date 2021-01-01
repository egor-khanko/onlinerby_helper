require 'yaml/store'

class SettingsStore
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

  def read(which)
    store.transaction { store[which] }
  end
end
