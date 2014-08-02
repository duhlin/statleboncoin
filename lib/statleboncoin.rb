require "statleboncoin/version"

require 'statleboncoin/database'
require 'statleboncoin/analysis'
require 'statleboncoin/connection'

Prix_max = 9_001 #10_500

module Statleboncoin
	def self.update_db
		@@update_db || false
	end
	def self.run( update_db = false )
		@@update_db = update_db
		db = db_connect

		#touran
		puts 'touran'
		www_lookup db, type: 'voitures', model: 'volkswagen touran', search: 'volkswagen%20touran', pattern: /touran/
		do_analysis db,  model: 'volkswagen touran', filter: Proc.new{|e| e[:annee] >= 2008  and e[:prix]<= 15000 and [38,69].include? (e[:code_postal]/1000).to_i and e[:kilometrage]<50000}

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

