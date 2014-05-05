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
		String :model
		String :pattern
	end

	db.create_table? :sent do
		String :href, :primary_key=>true
		DateTime :sent_at
	end

	db
end
