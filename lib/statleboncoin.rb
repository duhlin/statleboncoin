require "statleboncoin/version"

require 'statleboncoin/database'
require 'statleboncoin/analysis'
require 'statleboncoin/connection'

Prix_max = 10_500

module Statleboncoin
	def self.run( update_db = false )
		db = db_connect

		#HYPERSTRADA
		puts 'HYPERSTRADA'
		www_lookup  db, 'hyperstrada', /ducati.*hyper.*strada/, update_db 
		do_analysis db, 'hyperstrada', db[:motos].where(model: "hyperstrada"), Prix_max

		#HYPERMOTARD
		puts "HYPERMOTARD"
		www_lookup db, 'hypermotard', /ducati.*hyper.*motard/, update_db
		do_analysis db, 'hypermotard', db[:motos].where(model: "hypermotard").where(Sequel.like(:titre, '%821%')), Prix_max
	
		#MULTISTRADA
		puts 'MULTISTRADA'
		www_lookup db, 'multistrada', /ducati.*multi.*strada/, update_db 
		do_analysis db, 'multistrada', db[:motos] .where(model: 'multistrada', cylindree: '1 200 cm3'), Prix_max
	
		#800GS
		puts "f800gs"
		www_lookup db, 'bmw%20gs', /bmw.*gs/, update_db
		do_analysis db, 'f800gs', db[:motos].where(model: "bmw%20gs", cylindree: "800 cm3").where(Sequel.like(:titre, '%800%')) .exclude(Sequel.like(:titre, '%700%')).exclude(Sequel.like(:titre, '%650%')), Prix_max
		
		#R1200GS
		puts 'R1200GS'
		do_analysis db, 'R1200GS', db[:motos].where(model: 'bmw%20gs', cylindree: '1 200 cm3'), Prix_max
	
		#990 SMT
		puts '990 SMT'
		www_lookup  db, '990%20smt', /ktm.*990.*smt/, update_db 
		do_analysis db, '990 smt', db[:motos].where(model: '990%20smt'), Prix_max
	
		#1190 adventure
		puts '1190 Adventure'
		www_lookup db, '1190%20adventure', /1190.*adventure/, update_db
		do_analysis db, '1190 adventure', db[:motos].where(model: '1190%20adventure'), Prix_max
	
		#Tiger 800
		puts 'Tiger'
		www_lookup  db, 'triumph', /tiger/, update_db 
		do_analysis db, 'tiger 800', db[:motos].where(model: 'triumph', cylindree: '800 cm3'), Prix_max
		do_analysis db, 'tiger 1050', db[:motos].where(model: 'triumph', cylindree: '1 050 cm3'), Prix_max
		do_analysis db, 'tiger 1050 sport', db[:motos].where(model: 'triumph', cylindree: '1 050 cm3').where(Sequel.ilike(:titre, '%sport%')), Prix_max
		do_analysis db, 'tiger 1200', db[:motos].where(model: 'triumph', cylindree: '1 200 cm3'), Prix_max

		#Yamaha MT 07
		#puts 'Yamaha MT'
		#www_lookup db, 'mt%2007', /yamaha.*mt.*07/, update_db
		#do_analysis db, 'yamaha mt07', db[:motos].where(model: 'mt%2007')

		##Yamaha MT 09
		#www_lookup db, 'mt%2009', /yamaha.*mt.*09/, update_db
		#do_analysis db, 'yamaha mt09', db[:motos].where(model: 'mt%2009')

	end

	def self.run_forever(timeout=7_200)
		while true
			tstart = Time.now
			puts "Started at #{tstart.asctime}"
			self.run
			tend = Time.now
			puts "Finished at #{tend.asctime} in #{(tend-tstart).round(2)}s"
			puts "sleeping #{timeout}s"
			sleep timeout
		end
	end
end

