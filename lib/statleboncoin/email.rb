require 'net/smtp'

def send_email(topic, annonces, to_from=ARGV[0], pwd=ARGV[1])

	msgstr = <<END_OF_MESSAGE
From: lionel <#{to_from}>
To: lionel <#{to_from}>
Subject: meilleures annonces #{topic}
Date: #{Time.now.asctime}

#{annonces}
END_OF_MESSAGE
	smtp = Net::SMTP.new 'smtp.gmail.com', 587
	smtp.enable_starttls() 
	smtp.start('gmail.com', to_from, pwd, :plain) do |m|
		m.send_message msgstr, to_from, to_from
	end
	puts "new email #{topic} sent"
end


