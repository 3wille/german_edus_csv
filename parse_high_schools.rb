#!/usr/bin/env ruby
# frozen_string_literal: true

require 'nokogiri'
require 'net/http'
require 'csv'

require 'active_support'
require 'active_support/core_ext'

def main()
  # get the HTML from the website
  uri  = URI("https://de.wikipedia.org/wiki/Liste_der_Hochschulen_in_Deutschland")
  body = Net::HTTP.get(uri)
  doc = Nokogiri::HTML(body)

  table = doc.css("table")

  headers = table.css("tr th").map do |header|
    header.text.gsub("-\n", "")
  end

  # drop the table header as somehow nokogiri does not have thead and tbody
  # elements
  rows = table.css("tr").drop(1)
  highschools = build_highschools(rows, headers)
  highschools.each do |highschool|
    highschool["URL"] = get_website_url(highschool[:wiki_url])
  end

  highschools.reject! do |highschool|
    highschool["URL"].blank?
  end

  write_to_csv(highschools, headers)
end

def write_to_csv(highschools, headers)
  CSV.open("hochschulen.csv", "wb", col_sep: ";") do |csv|
    csv << ["URL"] + headers
    highschools.each do |highschool|
      csv << [highschool["Name"], highschool["Land"], highschool["Träger"], highschool["Promotionsrecht"], highschool["Gründung"], highschool["Studierende"], highschool["Stand"]]
    end
  end
end

def get_website_url(wiki_url)
  highschool_doc = Nokogiri::HTML(Net::HTTP.get(URI("https://de.wikipedia.org#{wiki_url}")))

  infobox = highschool_doc.css("#Vorlage_Infobox_Hochschule")
  website_row = infobox.css("tr").select do |row|
    row.css("th").text.eql?("Website")
  end
  link = website_row&.first&.css("a")
  unless link&.empty?
    url = link&.attribute("href")&.value
  end
  puts url

  url
end

def build_highschools(rows, headers)
  name_index = headers.index do |header|
    header.eql?("Name")
  end

  highschools = []
  rows.each do |row|
    highschool = {}
    columns = row.css("td")
    highschool[:wiki_url] = columns[name_index].css("a").attribute("href").value
    columns.each_with_index do |column, index|
      # last child to workaround a display:none element in stud count column
      text = column&.children&.last&.text

      highschool[headers[index]] = text
    end
    highschools << highschool
  end
  highschools
end

main
