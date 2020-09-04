require 'nokogiri'
require 'httparty'
require 'byebug'
require 'json'

FILE_PATH = "parsed_json.txt"

def get_json
  parsed_json_array = []
  page_number = 0
  last_page = nil

  loop do
    page_number += 1
    url = 'https://catalog.onliner.by/sdapi/catalog.api/search/hdd?page='+page_number.to_s #generating a URL for a request


    unparsed_json = HTTParty.get(url).to_s #getting json from API
    parsed_json = JSON.parse(unparsed_json)
    parsed_json_array.push(parsed_json) #making an array of parsed JSONs

    if last_page.nil? #defining last page i not already defined
      last_page = parsed_json["page"]["last"]
    end

    if File.exists?(FILE_PATH)
      File.foreach(FILE_PATH){|json_page_string| parsed_json_array.push(eval(json_page_string))} #converting string to hash
      break
    end

    puts "Getting page  № #{page_number}" #notifying the user about the progress
    if page_number == last_page
      puts "Parsing is done!"
      break
    end
  end

  if !File.exists?(FILE_PATH)
    File.write(FILE_PATH, parsed_json_array.join("\n"), mode: "a")
  end

  return parsed_json_array
end

def scraper
  products = []
  products_cleaned = []
  products_info = Hash.new()


  get_json.each{ |value| value["products"].each_with_index{|value, index| products.push(value)}} #extracting products from json into "products" array
  
  products.each{|value| if value["prices"] != nil then products_cleaned.push(value) end} #making a new array of products without price

  products_cleaned.each_with_index{ #removing all unnecessary info from array
    |value, index|
    if !value["full_name"].match(/[0-9.]{1,4}( )?(TB|GB|Гб|Тб)/).nil?
      products_info[value["full_name"]] = { 
        "volume_str" => value["full_name"][/[0-9.]{1,4}( )?(TB|GB|Гб|Тб)/],
        "price"  => value["prices"]["price_min"]["amount"]
      }
    end
  }

  products_info.each{|key, value| #making a float volume in TB from string
    if products_info[key]["volume_str"].match(/TB|Тб/)
      products_info[key]["volume"] = products_info[key]["volume_str"][/[\d.]{1,}/].to_f
    elsif products_info[key]["volume_str"].match(/GB|Гб/)
      products_info[key]["volume"] = products_info[key]["volume_str"][/[\d.]{1,}/].to_f/1000
    end
  }

  products_info.each{|key, value| #calculating value for each drive
    value["value"] = value["price"].to_f/value["volume"]
  }

  products_info = products_info.sort_by{|key, value| value["value"] } #sorting array by value

  products_info.each{|key, value| #outputing array name and value
    puts "#{key} at #{value["value"].round(2)} BYN/TB"
  }
  
end

scraper