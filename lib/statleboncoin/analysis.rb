require 'sequel'
require 'statsample'
require_relative 'email'
require_relative 'database'
require_relative 'connection'

CURRENT_YEAR = Time.now.year

def print_regression( out, model, result )
	lr = result[:result]
	out << " regression #{model}:\n"
	out << "  prix = #{lr.constant} + #{lr.coeffs[:annee].to_i} * annee + #{lr.coeffs[:kilometrage].round(3)} * kilometrage\n"
	out << "  prix neuf: #{result[:prix_neuf].to_i}\n"
	out << "  age max: #{result[:age_max].to_i}\n"
	out << "  kilometrage max: #{result[:kil_max].to_i}\n"
end

def regression(motos)
	puts " regression using #{motos.count} motos"

	ds = {
		kilometrage: motos.map{ |m| m[:kilometrage].to_f }.to_scale,
		annee:       motos.map{ |m| m[:annee].to_f }.to_scale,
		prix:        motos.map{ |m| m[:prix].to_f }.to_scale,
	}.to_dataset

	lr = Statsample::Regression.multiple(ds, :prix)
	result = {
		result: lr,
		prix_neuf: lr.constant + CURRENT_YEAR*lr.coeffs[:annee],
		age_max: CURRENT_YEAR + lr.constant/lr.coeffs[:annee],
		kil_max: -(lr.constant + CURRENT_YEAR*lr.coeffs[:annee])/lr.coeffs[:kilometrage]
	}
end

def home_eval(m, prix_neuf)
	m[:prix_attendu_usure] = prix_neuf * (1 - 0.5*((2014-m[:annee])/12.0 + (m[:kilometrage])/70_000.0))
	m[:prix].to_f - m[:prix_attendu_usure]
end

def sort( db, model, motos, reg_eval_proc, home_eval_proc )
	puts " sorting ads for #{model}"
	motos = motos.exclude(kilometrage: nil).exclude(annee: nil).exclude(prix: nil).to_a
	motos.map(&home_eval_proc)
	motos.map(&reg_eval_proc)
	best_reg = motos.sort_by(&reg_eval_proc).first(10)
	best_reg_href = best_reg.map{|m| m[:href]}
	best_home = motos.sort_by(&home_eval_proc).first(10).select{|m| !best_reg_href.include? m[:href]}

	best_reg = remove_sent( db, best_reg )
	best_home = remove_sent( db, best_home )

	{reg: best_reg, home: best_home}
end

def eval_prix_proc( reg )
	lr = reg[:result]
	eval_prix = Proc.new do |m|
		m[:prix_attendu] = lr.constant +
			lr.coeffs[:kilometrage]*m[:kilometrage] +
			lr.coeffs[:annee]*m[:annee]
		m[:prix].to_f - m[:prix_attendu]

	end

end

def do_mail( db, model, reg, best)
	if best[:reg].any? || best[:home].any?
		print_annonce = Proc.new do |m|
			puts m
			"#{(m[:prix]-m[:prix_attendu]).to_i}/#{(m[:prix]-m[:prix_attendu_usure]).to_i}\t" + 
			m.values.join("\t")
		end

		annonces_report = 
			"Best by regression:\n" +
			best[:reg].map(&print_annonce).join("\n") + "\n" +
			"Best by home eval:\n" +
			best[:home].map(&print_annonce).join("\n") + "\n\n"

		print_regression(annonces_report, model, reg)

		yield model, annonces_report
		add_to_sent( db, best[:reg] )
		add_to_sent( db, best[:home] )
	end


end

def do_analysis( db, model, motos )
	reg = regression(motos)
	print_regression($stdout, model, reg)

	best = sort(
		db,
		model,
		motos,
		eval_prix_proc(reg),
		Proc.new{ |m| home_eval(m, reg[:prix_neuf]) }
	)

	do_mail( db, model, reg, best) {|model, annonces_report| send_email(model, annonces_report)}

end

