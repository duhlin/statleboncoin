require 'nokogiri'
require 'net/http'

URL = 'www.leboncoin.fr'

class Search
	attr_reader :doc

	def initialize( req ) 
		puts "New Search #{req}"
		if req.start_with? '/'
			html = Net::HTTP.get( URL, req ) 
		else
			uri = URI.parse req
			html =  Net::HTTP.get( uri )
		end
		@doc = Nokogiri::HTML html

	end

	def list
		@doc.xpath '//div[@class="list-lbc"]/a'
	end

	def items
		l = list.map{ |i| Item.new i.attributes['href'] }
		n = next_page
		l.concat( n.items || [] ) if n
		l
	end

	def next_page
		n = @doc.xpath( '//nav//li[@class="page"]/a' ) || []
		n = n.select{ |i| i.text=='Page suivante' }
		if n.any?
			puts n.inspect
			link = n.first.attributes['href'].to_s
			puts link
			Search.new link if link
		else
			nil
		end
	end


end

class Item
	attr_reader :attr
	def initialize( href )
		puts "New Item #{href}"
		uri = URI.parse href
		@doc = Nokogiri::HTML Net::HTTP.get( uri )
		@attr = {}
		@attr['href'] = href
		@attr['title'] = title
		table = @doc.xpath '//div[@class="lbcParams floatLeft"]/table/tr' #/tbody/tr'
		table.each do |l|
			#puts l.xpath('th').text
			@attr[ l.xpath('th').text.downcase.strip ] = l.xpath('td').text.strip
		end
	end

	def title
		t = @doc.xpath('//h2[@id="ad_subject"]')
		t = t.first.text.strip if t and t.any?
	end

	def content
		t = @doc.xpath('//div[@class="content"]')
		t = t.first.text.strip if t and t.any?
	end

end

def print_items(out, items)
	if items.any?
		keys = items.first.attr.keys
		out.puts keys.join("\t")
		items.each do |it|
			out.puts keys.map{ |k| it.attr[k] }.join("\t")
		end
	end
end

#c = Search.new '/motos/?q=hyperstrada' 
#c = Search.new '/motos/?q=ducati'
#all_moto = c.items

#open('all_moto.csv', 'w') do |f|
#	print_items(f, all_moto)
#end

open('hyperstrada.csv', 'w') do |f|
	c = Search.new '/motos/?q=hyperstrada' 
	print_items(f, c.items.select{|moto| moto.attr['title'].to_s.downcase =~ /ducati.*hyperstrada/})
end

open('multistrada.csv', 'w') do |f|
	c = Search.new '/motos/?q=multistrada' 
	print_items(f, c.items.select{|moto| moto.attr['title'].to_s.downcase =~ /multi.*strada/})
end

