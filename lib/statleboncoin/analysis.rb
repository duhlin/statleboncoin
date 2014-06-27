require 'sequel'
require 'statsample'
require_relative 'email'
require_relative 'database'
require_relative 'connection'

CURRENT_YEAR = Time.now.year

def print_regression( out, model, result )
	lr = result[:result]
	out << " regression #{model}:\n"
	out << "  prix = #{lr.constant} + #{(lr.coeffs[:annee]||0).to_i} * annee + #{(lr.coeffs[:kilometrage]||0).round(3)} * kilometrage\n"
	out << "  prix neuf: #{result[:prix_neuf].to_i}\n"
	out << "  age max: #{result[:age_max].to_i}\n" if result[:age_max].finite?
	out << "  kilometrage max: #{result[:kil_max].to_i}\n"
end

def add_to(ds, motos, key)
	l = motos.map{|m| m[key]}
	ds[key] = l.to_scale if l.sort.uniq.count > 1
end

def regression(motos)
	puts " regression using #{motos.count} motos"

	ds = {}
	add_to ds, motos, :kilometrage
	add_to ds, motos, :annee
	add_to ds, motos, :prix
	ds = ds.to_dataset

	lr = Statsample::Regression.multiple(ds, :prix)
	puts lr.summary
	c_annee = lr.coeffs[:annee] || 0
	c_kilometrage = lr.coeffs[:kilometrage] || 0
	result = {
		result: lr,
		prix_neuf: lr.constant + CURRENT_YEAR*c_annee,
		age_max: CURRENT_YEAR + lr.constant/c_annee,
		kil_max: -(lr.constant + CURRENT_YEAR*c_annee)/c_kilometrage
	}
end

def home_eval(m, prix_neuf)
	m[:prix_attendu_usure] = prix_neuf * (1 - 0.5*((2014-m[:annee])/12.0 + (m[:kilometrage])/70_000.0))
	m[:diff_prix_attendu_usure] = m[:prix].to_f - m[:prix_attendu_usure]
end

def sort( db, model, motos, reg_eval_proc, home_eval_proc, prix_max )
	puts " sorting ads for #{model}"
	motos = motos.to_a
	motos.map(&home_eval_proc)
	motos.map(&reg_eval_proc)
	best_home = motos.sort_by(&home_eval_proc).select{|m| !prix_max || m[:prix] < prix_max}.first(10)
	best_reg = motos.sort_by(&reg_eval_proc).select{|m| !prix_max || m[:prix] < prix_max}.first(10)

	#remove duplicates
	hrefs = best_home.map{|m| m[:href]}
	best_reg = best_reg.select{|m| !hrefs.include? m[:href]}

	{reg: best_reg, home: best_home}
end

def eval_prix_proc( reg )
	lr = reg[:result]
	eval_prix = Proc.new do |m|
		m[:prix_attendu] = lr.constant +
			(lr.coeffs[:kilometrage]||0)*m[:kilometrage] +
			(lr.coeffs[:annee]||0)*m[:annee]
		m[:diff_prix_attendu] = m[:prix].to_f - m[:prix_attendu]

	end

end

def do_mail( db, model, reg, best, columns=[:diff_prix_attendu, :diff_prix_attendu_usure, :prix, :href, :titre, :ville, :code_postal, :annee, :kilometrage])
	#mark the one that have already been sent
	best_reg = mark_sent( db, best[:reg] )
	best_home = mark_sent( db, best[:home] )

	print_annonce = Proc.new do |m,i|
		s = "##{i+1}\t"
		if m[:sent?]
			s << "\t"
		else
			s << "NEW\t"
		end
		s << columns.map do |k| 
			r = m[k]
			r = r.to_i if r.kind_of? Float
			r
		end.join("\t")
		s
	end

	annonces_report = 
		"Best by home eval:\n" +
		"\t\t" + columns.map(&:to_s).join("\t") + "\n" +
		best[:home].each_with_index.map(&print_annonce).join("\n") + "\n" +
		"Best by regression:\n" +
		"\t\t" + columns.map(&:to_s).join("\t") + "\n" +
		best[:reg].each_with_index.map(&print_annonce).join("\n") + "\n\n"

	print_regression(annonces_report, model, reg)

	yield model, annonces_report, (best[:reg].select{|m| !m[:sent?]}.any? || best[:home].select{|m| !m[:sent?]}.any?)
	add_to_sent( db, best[:reg] )
	add_to_sent( db, best[:home] )


end

def remove_inactive( list )
	list.select!{|e| Item.new( e[:href] ).title}
end

def do_analysis( db, model, motos, prix_max = nil )
	motos = motos.exclude(kilometrage: nil).exclude(annee: nil).exclude(prix: nil).exclude(prix: 0..4500)
	reg = regression(motos)

	best = sort(
		db,
		model,
		motos,
		eval_prix_proc(reg),
		Proc.new{ |m| home_eval(m, reg[:prix_neuf]) },
        prix_max
	)

	remove_inactive( best[:reg] )
	remove_inactive( best[:home] )

	do_mail( db, model, reg, best) do |model, annonces_report, has_new|
		puts " send email (has_new: #{has_new}):"
		print annonces_report
		send_email(model, annonces_report) if has_new
	end

end

