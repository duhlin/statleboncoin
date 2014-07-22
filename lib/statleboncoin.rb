require "statleboncoin/version"

require 'statleboncoin/database'
require 'statleboncoin/analysis'
require 'statleboncoin/connection'

Prix_max = 9_001 #10_500

module Statleboncoin
	def self.run( update_db = false )
		db = db_connect

		#kawasaki
		puts 'versys 1000'
		www_lookup  db, 'versys', /versys/i, update_db 
		do_analysis db, 'versys', db[:motos].where(model: 'versys').where(Sequel.like(:titre, '%1000%')), Prix_max

		#aprilia
		puts 'caponord'
		www_lookup  db, 'caponord', /caponord/i, update_db 
		do_analysis db, 'caponord', db[:motos].where(model: 'caponord', cylindree: '1 200 cm3'), Prix_max

		#VSTROM 1000
		puts 'VSTROM'
		www_lookup  db, 'vstrom', /v.*strom/i, update_db 
		www_lookup  db, 'v%20strom', /v.*strom/i, update_db 
		do_analysis db, 'vstrom', db[:motos].where(model: ['vstrom','v%20strom']).where{annee >= 2012}.where(Sequel.like(:titre, '%1000%')), Prix_max

		#HYPERSTRADA
		puts 'HYPERSTRADA'
		www_lookup  db, 'hyperstrada', /ducati.*hyper.*strada/i, update_db 
		do_analysis db, 'hyperstrada', db[:motos].where(model: "hyperstrada"), Prix_max

		#HYPERMOTARD
		puts "HYPERMOTARD"
		www_lookup db, 'hypermotard', /ducati.*hyper.*motard/i, update_db
		do_analysis db, 'hypermotard', db[:motos].where(model: "hypermotard").where(Sequel.like(:titre, '%821%')), Prix_max

		#MULTISTRADA
		puts 'MULTISTRADA'
		www_lookup db, 'multistrada', /ducati.*multi.*strada/i, update_db 
		do_analysis db, 'multistrada', db[:motos] .where(model: 'multistrada', cylindree: '1 200 cm3'), Prix_max

		#800GS
		puts "f800gs"
		www_lookup db, 'bmw%20gs', /bmw.*gs/i, update_db
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
		www_lookup  db, 'triumph', /tiger|speed|street/, update_db 
		do_analysis db, 'tiger 800', db[:motos].where(model: 'triumph', cylindree: '800 cm3').where(Sequel.ilike(:titre, '%tiger%xc%')), Prix_max
		do_analysis db, 'tiger 1050', db[:motos].where(model: 'triumph', cylindree: '1 050 cm3').where(Sequel.ilike(:titre, '%tiger%')), Prix_max
		do_analysis db, 'tiger 1050 sport', db[:motos].where(model: 'triumph', cylindree: '1 050 cm3').where(Sequel.ilike(:titre, '%tiger%sport%')), Prix_max
		do_analysis db, 'tiger 1200', db[:motos].where(model: 'triumph', cylindree: '1 200 cm3').where(Sequel.ilike(:titre, '%tiger%')), Prix_max
		#do_analysis db, 'speed triple', db[:motos].where(model: 'triumph').where(Sequel.ilike(:titre, '%speed%triple%')), Prix_max
		#do_analysis db, 'street triple', db[:motos].where(model: 'triumph').where(Sequel.ilike(:titre, '%street%triple%')), Prix_max

		##Yamaha MT 07
		#puts 'Yamaha MT'
		#www_lookup db, 'mt%2007', /yamaha.*mt.*07/, update_db
		#do_analysis db, 'yamaha mt07', db[:motos].where(model: 'mt%2007')

		###Yamaha MT 09
		#www_lookup db, 'mt%2009', /yamaha.*mt.*09/, update_db
		#do_analysis db, 'yamaha mt09', db[:motos].where(model: 'mt%2009')

		#puts 'Honda cb 1000'
		#www_lookup db, 'honda%20cb%201000', /honda.*cb.*1000/, update_db
		#do_analysis db, 'honda cb 1000', db[:motos].where(model: 'honda%20cb%201000'), Prix_max
		#
		#puts 'Honda vfr 800'
		#www_lookup db, 'honda%20vfr', /honda.*vfr/, update_db
		#do_analysis db, 'honda vfr 800', db[:motos].where(model: 'honda%20vfr', cylindree: '800 cm3'), Prix_max
		

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

