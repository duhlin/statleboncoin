# Statleboncoin

Request ads from leboncoin.fr and sort them

## Installation

Make sure that ruby is installed. Install has been tested on windows using Ruby 2.0.0-p481 (x64) from: http://rubyinstaller.org/downloads/

Install bundler if needed:

    $ gem install bundler
    
Get source code from github

    $ git clone https://github.com/duhlin/statleboncoin.git

And use bundler to install required gems:

    $ bundle install

And then execute analysis:

    $ bundle exec ruby bin/check_moto_leboncoin xxxxx@gmail.com password


## Contributing

1. Fork it ( https://github.com/[my-github-username]/statleboncoin/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
