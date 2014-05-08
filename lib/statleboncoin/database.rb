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

	db
end

def add_to_sent(db, items)
	items.each do |i|
		db[:sent].insert( href: i[:href], sent_at: Time.now ) rescue Sequel::UniqueConstraintViolation
	end
end

def mark_sent(db, items)
	items.each{ |m| m[:sent?] = db[:sent].where(href: m[:href]).any? }
end

