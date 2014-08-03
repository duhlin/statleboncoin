require 'sequel'

def db_connect()
	db = Sequel.connect('sqlite://leboncoin.db')

	db.create_table? :motos do
		String :href, :primary_key=>true
		String :titre
		String :ville
		Integer :code_postal
		Integer :kilometrage
		Integer :annee
		Integer :prix
		String :cylindree
		DateTime :stored_at, :default=>Sequel::SQL::Function.new(:now)
		String :content
		String :model
		String :pattern
	end

	db.create_table? :sent do
		String :href, :primary_key=>true
		DateTime :sent_at
	end

	db.create_table? :analysis do
		String :href
		DateTime :stored_at
		String :formula
		Integer :prix_neuf
		Integer :prix_reg
		Integer :prix_home
		primary_key [:href, :stored_at]
	end

	db
end

def add_to_sent(db, items)
	db.transaction do
		items.each do |i|
			db[:sent].insert( href: i[:href], sent_at: Time.now ) rescue Sequel::UniqueConstraintViolation
		end
	end
end

def register_analysis(db, href, prix_neuf, prix_reg, prix_home)
	db[:analysis].insert( 
			     href: href,
			     stored_at: Time.now,
			     prix_neuf: prix_neuf.to_i,
			     prix_reg: prix_reg.to_i,
			     prix_home: prix_home.to_i
			    )
end

def mark_sent(db, items)
	items.each{ |m| m[:sent?] = db[:sent].where(href: m[:href]).any? }
end

def store_db(db, items, lookup, update_db)
	motos = db[:motos]
	db.transaction do
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
				motos.insert( attributes )
			rescue Sequel::UniqueConstraintViolation
				motos.where(href: attributes[:href]).update( attributes ) if update_db
			end
		end
	end
end
