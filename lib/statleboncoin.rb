require "statleboncoin/version"

require 'statleboncoin/database'
require 'statleboncoin/analysis'
require 'statleboncoin/connection'


module Statleboncoin
	def self.run
		db = db_connect

		#800GS
		puts "f800gs"
		www_lookup( db, 'bmw%20gs', /bmw.*gs/ )
		do_analysis db, 'f800gs', db[:motos].where(model: "bmw%20gs", cylindree: "800 cm3").where(Sequel.like(:titre, '%800%')) .exclude(Sequel.like(:titre, '%700%')).exclude(Sequel.like(:titre, '%650%')).exclude(prix: 0..5000)
		
		#R1200GS
		puts 'R1200GS'
		do_analysis db, 'R1200GS', db[:motos].where(model: 'bmw%20gs', cylindree: '1 200 cm3')

		#HYPERSTRADA
		puts 'HYPERSTRADA'
		www_lookup  db, 'hyperstrada', /ducati.*hyper.*strada/ 
		do_analysis db, 'hyperstrada', db[:motos].where(model: "hyperstrada")

		#MULTISTRADA
		puts 'MULTISTRADA'
		www_lookup db, 'multistrada', /ducati.*multi.*strada/ 
		do_analysis db, 'multistrada', db[:motos] .where(model: 'multistrada', cylindree: '1 200 cm3')

		#990 SMT
		puts '990 SMT'
		www_lookup  db, '990%20smt', /ktm.*990.*smt/ 
		do_analysis db, '990 smt', db[:motos].where(model: '990%20smt')

		#Tiger 800
		puts 'Tiger'
		www_lookup  db, 'triumph', /tiger/ 
		do_analysis db, 'tiger 800', db[:motos].where(model: 'triumph', cylindree: '800 cm3').exclude(prix: 0..5000)

	end
end

