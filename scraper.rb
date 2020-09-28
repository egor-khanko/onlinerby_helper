#!/usr/bin/env ruby

require 'nokogiri'
require 'httparty'
require 'byebug'
require 'json'

FILE_PATH = "parsed_json.txt"

def get_json
  parsed_json_array = []
  page_number = 0
  last_page = nil
  file_exists = File.exists?(FILE_PATH)

  loop do
    page_number += 1
    url = 'https://catalog.onliner.by/sdapi/catalog.api/search/hdd?page='+page_number.to_s #generating a URL for a request

    unparsed_json = HTTParty.get(url).to_s # get json from API
    parsed_json = JSON.parse(unparsed_json)
    parsed_json_array.push(parsed_json) # make an array of parsed JSONs

    # define last page if not already defined
    if last_page.nil?
      last_page = parsed_json.dig('page', 'last')
    end

    if file_exists
      File.foreach(FILE_PATH) do |json_page_string|
        # convert string to hash
        parsed_json_array.push(JSON.parse(json_page_string))
      end
      break
    else
      File.write(FILE_PATH, unparsed_json + "\n", mode: "a")
    end

    # notify the user about the progress
    print "Retrieving page ##{page_number}\r"
    break puts "\nParsing is done!" if page_number == last_page
  end

  parsed_json_array
end

def scraper
  products = []
  products_cleaned = []
  products_info = {}

  # extract products from json into "products" array
  get_json.each { |value| value["products"].each_with_index { |value, index| products.push(value) } }

  # makes a new array of products without price
  products.each { |value| if value["prices"] != nil then products_cleaned.push(value) end }
  products.each { |value| products_cleaned.push(value) if value["prices"] }

  #remove all unnecessary info from array
  products_cleaned.each_with_index do |value, index|
    if value["full_name"].match(/[0-9.]{1,4}( )?(TB|GB|Гб|Тб)/)
      products_info[value["full_name"]] = {
        "volume_str" => value["full_name"][/[0-9.]{1,4}( )?(TB|GB|Гб|Тб)/],
        "price"  => value.dig('prices', 'price_min', 'amount')
      }
    end
  end

  products_info.each do |key, value| # make a float volume in TB from string
    if products_info[key]["volume_str"].match(/TB|Тб/)
      products_info[key]["volume"] = products_info[key]["volume_str"][/[\d.]{1,}/].to_f
    elsif products_info[key]["volume_str"].match(/GB|Гб/)
      products_info[key]["volume"] = products_info[key]["volume_str"][/[\d.]{1,}/].to_f / 1000
    end
  end

  products_info.each do |_key, value| # calculate value for each drive
    value["value"] = (value['price'].to_f / value['volume']).round(2)
  end

  products_info = products_info.sort_by{|_key, value| value['value'] } # sort array by value

  products_info.each do |key, value| # output array name and value
    puts "#{key} at #{value['value']} BYN/TB"
  end
end

scraper
