# frozen_string_literal: true

require 'faraday'
require 'nokogiri'

module Statleboncoin
  class HTTPCrawler
    URL = 'https://www.leboncoin.fr'
    DEFAULT_HEADERS = {
      'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:130.0) Gecko/20100101 Firefox/130.0',
      'Accept' => 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/png,image/svg+xml',
      'Accept-Language' => 'fr,fr-FR;q=0.8,en-US;q=0.5,en;q=0.3',
      'Accept-Encoding' => 'deflate, br, zstd',
      'DNT' => '1',
      'Connection' => 'keep-alive',
      'Upgrade-Insecure-Requests' => '1',
      'TE' => 'chunked'
    }.freeze

    class RecherchePage
      def initialize(content)
        @doc = Nokogiri::HTML content
      end

      def items
        # items are defined in json format, like this <script id="__NEXT_DATA__" type="application/json">...json...</script>
        next_data = @doc.at_css('script#__NEXT_DATA__')
        raise "Can't find <script id=\"__NEXT_DATA__\"> in received html document" unless next_data

        json = JSON.parse next_data.text
        json.dig('props', 'pageProps', 'searchData', 'ads')
      end

      def next_page
        # return the next page if it exists
      end
    end

    def initialize
      @conn = Faraday.new(
        url: URL,
        headers: DEFAULT_HEADERS
      )
    end

    def get(path)
      res = @conn.get path
      raise "unexpected status #{res.status}" unless res.status == 200

      res
    end

    def recherche(params, from_index_date: nil)
      return enum_for(:recherche, params, from_index_date: from_index_date) unless block_given?

      raise 'parms must be a string' unless params.is_a? String
      raise 'params must not include page=<id>' if params.include? 'page='

      page_id = 1

      loop do
        res = get "/recherche?#{params}&page=#{page_id}"
        raise 'unexpected content-type' unless res.headers['content-type'] == 'text/html; charset=utf-8'

        page = RecherchePage.new res.body
        break unless page.items&.any?

        yield page
        # items are expected to be sorted by index_date descending,
        # no need to fetch more pages if we already have items older than from_index_date
        break if from_index_date && page.items.last.fetch('index_date') < from_index_date

        page_id += 1
        # don't go too fast, sleep between 0.0 and 3.0 seconds
        # sleep rand(0.0..3.0)
      end
    end
  end
end
