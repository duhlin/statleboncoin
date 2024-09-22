# frozen_string_literal: true

require_relative 'statleboncoin/analysis'
require_relative 'statleboncoin/cli'
require_relative 'statleboncoin/database'
require_relative 'statleboncoin/http_crawler'
require_relative 'statleboncoin/car_item'
require_relative 'statleboncoin/version'

require 'mail'

module Statleboncoin
  class Error < StandardError; end
  # Your code goes here...
end
