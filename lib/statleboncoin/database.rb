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
	items.each do |i|
		db[:sent].insert( href: i[:href], sent_at: Time.now ) rescue Sequel::UniqueConstraintViolation
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

