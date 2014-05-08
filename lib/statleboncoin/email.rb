require 'net/smtp'

def send_email(topic, annonces, to_from=ARGV[0], pwd=ARGV[1])

	msgstr = <<END_OF_MESSAGE
From: lionel <#{to_from}>
To: lionel <#{to_from}>
Subject: meilleures annonces #{topic}
Date: #{Time.now.asctime}

#{annonces}
END_OF_MESSAGE
	puts pwd
	smtp = Net::SMTP.new 'smtp.gmail.com', 587
	smtp.enable_starttls() 
	smtp.start('gmail.com', to_from, pwd, :plain) do |m|
		m.send_message msgstr, to_from, to_from
	end
	puts "new email #{topic} sent"
end

def add_to_sent(db, items)
	items.each do |i|
		db[:sent].insert( href: i[:href], sent_at: Time.now )
	end
end

def remove_sent(db, items)
	items.select{|m| db[:sent].where(href: m[:href]).empty?}
end

