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
		#puts "New Search #{req}"
		if req.start_with? '/'
            puts "start with /: #{URL}, #{req}"
		else
			req.gsub!(' ', '%20')
			req = find_req( req )
            puts "do not start with /: #{URL}, #{req}"
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
		puts "New Item #{href}"
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

def store_db(dataset, items, lookup, update_db)
	items.each do |it|
		begin
			attributes = {
				href: it.attr['href'].to_s,
				titre: it.attr['title'].to_s,
				annee: to_integer( it.attr['année-modèle :'] ),
				prix: to_integer( it.attr['prix:'] ),
				ville: it.attr['ville :'].to_s,
				code_postal: to_integer( it.attr['code postal :'] ),
				kilometrage: to_integer( it.attr['kilométrage :'] ),
				cylindree: it.attr['cylindrée :'].to_s,
				content: it.attr['content'].to_s,
				stored_at: Time.now
			}.merge(lookup)
			dataset.insert( attributes )
		rescue Sequel::UniqueConstraintViolation
			dataset.where(href: attributes[:href]).update( attributes ) if update_db
		end
	end
end


def www_lookup( db, model, pattern, update_db )
	puts " retrieve from #{URL} for #{model}"
	c = Search.new "/motos/?q=#{model}" 
	motos = db[:motos]
	store_db(
		motos,
		c.items.select do |m|
			m['title'].to_s.downcase =~ pattern and (update_db or motos.where(href: m['href'].to_s).empty?)
		end.map{|m| Item.new m['href'].to_s},
		{model: model, pattern: pattern.to_s},
		update_db
	)
end


