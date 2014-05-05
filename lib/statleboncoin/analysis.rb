require 'sequel'
require 'statsample'
require_relative 'email'
require_relative 'database'
require_relative 'connection'

def regression(motos)
	puts " regression using #{motos.count} motos"

	ds = {
		kilometrage: motos.map{ |m| m[:kilometrage].to_f }.to_scale,
		annee:       motos.map{ |m| m[:annee].to_f }.to_scale,
		prix:        motos.map{ |m| m[:prix].to_f }.to_scale,
	}.to_dataset

	lr = Statsample::Regression.multiple(ds, :prix)

	eval_prix = Proc.new do |m|
		m[:prix_attendu] = lr.constant +
			lr.coeffs[:kilometrage]*m[:kilometrage] +
			lr.coeffs[:annee]*m[:annee]
		m[:prix].to_f - m[:prix_attendu]
	end
end

def home_eval(m, prix_neuf)
	m[:prix_attendu_usure] = prix_neuf * (1 - 0.5*((2014-m[:annee])/12.0 + (m[:kilometrage])/60_000.0))
	m[:prix].to_f - m[:prix_attendu_usure]
end

def sort_and_send_email( db, model, motos, reg_eval_proc, home_eval_proc )
	puts " sorting ads for #{model}"
	motos = motos.exclude(kilometrage: nil).exclude(annee: nil).exclude(prix: nil).to_a
	motos.map(&home_eval_proc)
	motos.map(&reg_eval_proc)
	best_reg = motos.sort_by(&reg_eval_proc).first(10)
	best_reg_href = best_reg.map{|m| m[:href]}
	best_home = motos.sort_by(&home_eval_proc).first(10).select{|m| !best_reg_href.include? m[:href]}

	best_reg = remove_sent( db, best_reg )
	best_home = remove_sent( db, best_home )

	if best_reg.any? || best_home.any?
		print_annonce = Proc.new do |m|
			puts m
			"#{(m[:prix]-m[:prix_attendu]).to_i}/#{(m[:prix]-m[:prix_attendu_usure]).to_i}\t" + 
			m.values.join("\t")
		end

		annonces_report = 
			"Best by regression:\n" +
			best_reg.map(&print_annonce).join("\n") + "\n" +
			"Best by home eval:\n" +
			best_home.map(&print_annonce).join("\n") 

		send_email(model, annonces_report)
		add_to_sent( db, best_reg )
		add_to_sent( db, best_home )
	end
end

def do_analysis( db, model, prix_neuf, motos )
	sort_and_send_email(
		db,
		model,
		motos,
		regression(motos),
		Proc.new{ |m| home_eval(m, prix_neuf) }
	)
end

