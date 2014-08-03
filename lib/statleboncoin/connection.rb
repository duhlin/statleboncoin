# encoding: utf-8

require 'nokogiri'
require 'net/http'
require_relative 'database'

URL = 'www.leboncoin.fr'

def find_req(uri)
	uri = uri.to_s
	uri[ uri.index(URL)+URL.size..-1 ]
end

class Search
	attr_reader :doc

	def initialize( req ) 
		puts "New Search #{req}"
		if req.start_with? '/'
		else
			req.gsub!(' ', '%20')
			req = find_req( req )
		end
		html =  Net::HTTP.get( URL, req )
		@doc = Nokogiri::HTML html.force_encoding(Encoding::ISO_8859_15)

	end

	def list
		@doc.xpath '//div[@class="list-lbc"]/a'
	end

	def items
		l = list.map{ |i| i.attributes }
		n = next_page
		l.concat( n.items || [] ) if n
		l
	end

	def next_page
		n = @doc.xpath( '//nav//li[@class="page"]/a' ) || []
		n = n.select{ |i| i.text=='Page suivante' }
		if n.any?
			link = n.first.attributes['href'].to_s
			Search.new link if link
		else
			nil
		end
	end


end

class Item
	attr_reader :attr
	def initialize( href )
		uri = URI.parse href
		req = find_req( uri )
		puts "Item: #{URL}, #{req}"
		@doc = Nokogiri::HTML Net::HTTP.get( URL, req ).force_encoding(Encoding::ISO_8859_15)
		@attr = {}
		@attr['href'] = href
		@attr['title'] = title
		@attr['content'] = content
		add_table('//table')
		add_table('//table/tr')
	end

	def add_table( xpath )
		@doc.xpath(xpath).each do |l|
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

def print_csv(out, items)
	if items.any?
		keys = items.first.attr.keys
		out.puts keys.join("\t")
		items.each do |it|
			out.puts keys.map{ |k| it.attr[k] }.join("\t")
		end
	end
end

def to_integer(val)
	val = val.sub(' ','').to_i unless val.nil?
	val
end

def www_lookup( db, lookup )
	model = lookup[:model]
	search = lookup[:search] || model
	type = lookup[:type]
	pattern = lookup[:pattern]
	puts " retrieve from #{URL} for #{model}"
	c = Search.new "/#{type}/?q=#{search}" 
	motos = db[:motos]
	store_db(
		db,
		c.items.select do |m|
			pattern.nil? or m['title'].to_s.downcase =~ pattern
		end.select do |m|
			Statleboncoin.update_db or motos.where(href: m['href'].to_s).empty?
		end.map{|m| Item.new m['href'].to_s},
		{model: model, pattern: pattern.to_s},
		Statleboncoin.update_db
	)
end


