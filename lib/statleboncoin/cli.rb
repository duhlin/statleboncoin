require 'thor'

module Statleboncoin
  class CLI < Thor
    BEST_DEAL_SIZE = 20
    SAMPLE_SIZE = 200

    desc 'recherche PARAMS',
         'Retrieve items from https://www.leboncoin.fr/recherche?PARAMS and store them in a database'
    method_options 'only-newer' => :boolean
    def recherche(params, database_file = 'statleboncoin.duckdb')
      puts "recherche #{params} #{options}"
      puts "Initializing database #{database_file}"
      db = Database.new(database_file)
      begin
        refresh(db, params, only_newer: options.fetch('only-newer', true))
      ensure
        db.close
      end
    end

    desc 'save_to_parquet DATABASE_FOLDER',
         'Export the database to DATABASE_FOLDER in parquet format'
    def save_to_parquet(database_folder, database_file = 'statleboncoin.duckdb')
      puts "save_to_parquet #{database_folder} #{database_file}"
      db = Database.new(database_file)
      db.save_to_parquet(database_folder)
      db.close
    end

    desc 'load_from_parquet DATABASE_FOLDER',
         'Load the database from DATABASE_FOLDER in parquet format'
    def load_from_parquet(database_folder, database_file = 'statleboncoin.duckdb')
      puts "load_from_parquet #{database_folder} #{database_file}"
      db = Database.new(database_file)
      db.load_from_parquet(database_folder)
      db.close
    end

    desc 'refresh_all',
         'Retrieve new items for all existing search in the database'
    def refresh_all(database_file = 'statleboncoin.duckdb')
      db = Database.new(database_file)
      begin
        crawler = HTTPCrawler.new
        db.query('select distinct search_params from raw_items union select distinct search_params from raw_items_archive').each do |params|
          refresh(db, params.first, crawler: crawler, only_newer: true)
        end
      ensure
        db.close
      end
    end

    LIST_MODELS_SQL = <<~SQL
      select
        model,
        count(*),
        count_if(coalesce(vehicle_damage, '') != 'damaged' and coalesce(car_contract, '') != '1')
      from car_items
      group by model
      order by count(*) desc
    SQL

    desc 'list_models',
         'List the models in the database'
    def list_models(database_file = 'statleboncoin.duckdb')
      db = Database.new(database_file)
      begin
        models = db.query(LIST_MODELS_SQL)
        model_max_size = models.map(&:first).map { |model| model&.size || 0 }.max
        puts "#{'Model'.ljust(model_max_size)} | Items | Excluding damaged and contract cars"
        models.each do |model, count, effective_count|
          puts "#{(model || '').ljust(model_max_size)} | #{count.to_s.rjust(5)} | #{effective_count.to_s.rjust(5)}"
        end
      ensure
        db.close
      end
    end

    desc 'analyze_car MODEL',
         'Return the best deals for a given FILTER'
    option :best_deal_size, type: :numeric, default: BEST_DEAL_SIZE
    option :max_price, type: :numeric
    option :max_mileage, type: :numeric
    option :max_age, type: :numeric
    def analyze_car(filter, database_file = 'statleboncoin.duckdb')
      db = Database.new(database_file)
      begin
        analyze_car_model(db, filter, options, $stdout)
      ensure
        db.close
      end
    end

    desc 'archive_raw_items',
         'Archive the raw_items table'
    def archive_raw_items(database_file = 'statleboncoin.duckdb')
      db = Database.new(database_file)
      begin
        db.archive_raw_items
      ensure
        db.close
      end
    end

    desc 'analyze_car_all',
         'Return the best deals for all models'
    option :best_deal_size, type: :numeric, default: BEST_DEAL_SIZE
    option :max_price, type: :numeric
    option :max_mileage, type: :numeric
    option :max_age, type: :numeric
    def analyze_car_all(database_file = 'statleboncoin.duckdb')
      db = Database.new(database_file)
      begin
        _analyze_car_all(db, options, $stdout)
      ensure
        db.close
      end
    end

    desc 'send_email',
         'Send an email with the best deals for all models'
    option :best_deal_size, type: :numeric, default: BEST_DEAL_SIZE
    option :max_price, type: :numeric
    option :max_mileage, type: :numeric
    option :max_age, type: :numeric
    option :smtp_server, type: :string, default: 'smtp.gmail.com'
    option :smtp_port, type: :numeric, default: 587
    option :smtp_domain, type: :string, default: 'gmail.com'
    option :smtp_user, type: :string, required: true
    option :smtp_password, type: :string, required: true
    option :smtp_authentication, type: :string, default: 'plain'
    option :smtp_from, type: :string, required: true
    option :smtp_to, type: :string, required: true
    def send_email(database_file = 'statleboncoin.duckdb')
      smtp_options = {
        address: options.fetch(:smtp_server),
        port: options.fetch(:smtp_port),
        domain: options.fetch(:smtp_domain),
        user_name: options.fetch(:smtp_user),
        password: options.fetch(:smtp_password),
        authentication: options.fetch(:smtp_authentication)
      }
      mail_to = options.fetch(:smtp_to)
      mail_from = options.fetch(:smtp_from)
      Mail.defaults do
        delivery_method :smtp, smtp_options
      end

      output = StringIO.new
      db = Database.new(database_file)
      begin
        items = _analyze_car_all(db, options, output)

        # force a message_id so that emails are threaded
        Mail.deliver do
          to mail_to
          from mail_from
          message_id 'c38f15ca-cfc5-4f30-9199-07f079ea62f8@statleboncoin'
          subject 'Statleboncoin best deals'
          body output.string
        end

        db.mark_url_as_sent(items.reject(&:sent_at).map(&:url))
      ensure
        db.close
      end
    end

    private

    ANALYZE_MIN_PRICE = 1_000

    ANALYZE_SQL = <<~SQL
      select * from (
        select distinct mileage, issuance_date, price -- use distinct because some items are duplicated
        from car_items
        where coalesce(model, '') = coalesce($model, '') and coalesce(vehicle_damage, '') != 'damaged' and coalesce(car_contract, '') != '1' and price > #{ANALYZE_MIN_PRICE}
      ) s using sample #{SAMPLE_SIZE}
    SQL

    BEST_DEALS_COLUMNS = {
      url: 'car_items.url',
      brand: 'brand',
      model: 'model',
      mileage: 'mileage',
      issuance_date: 'issuance_date',
      price: 'price',
      predicted_price: "$base_price + $cost_per_kms * mileage + $cost_per_day * date_diff('day', issuance_date, current_date()) as predicted_price",
      predicted_price2: "$base_price * (1 -  mileage / #{Analysis::HOME_PREDICT_MAX_MILEAGE} - date_diff('day', issuance_date, current_date())/#{Analysis::HOME_PREDICT_MAX_AGE_DAYS}) as predicted_price2",
      sent_at: 'sent_at'
    }
    BEST_DEALS_ITEMS = Struct.new(*BEST_DEALS_COLUMNS.keys) do
      def print(analysis)
        check_predicted_price = analysis.predict_price(self)
        if (check_predicted_price - predicted_price).abs > 50
          raise "unexpected diff: check_predicted_price=#{check_predicted_price} predicted_price=#{predicted_price}"
        end

        diff = (price - predicted_price).to_i.to_s.rjust(5)
        diff2 = (price - predicted_price2).to_i.to_s.rjust(5)
        mileage_s = mileage.to_s.rjust(7)
        price_s = price.to_s.rjust(5)
        new = sent_at.nil? ? ' **NEW**' : ''
        "#{brand} - #{model}, #{mileage_s} kms, #{issuance_date.strftime('%Y/%m')}: #{price_s} € (#{diff} € - #{diff2} €) #{url}#{new}"
      end
    end

    BEST_DEALS_SQL = <<~SQL
      select
        distinct #{BEST_DEALS_COLUMNS.values.join(', ')} -- use distinct because some items are duplicated
      from car_items
      left outer join sent_urls on sent_urls.url = car_items.url
      where coalesce(model, '') = coalesce($model, '')
        and coalesce(vehicle_damage, '') != 'damaged'
        and coalesce(car_contract, '') != '1'
        and price > #{ANALYZE_MIN_PRICE}
        and ($max_price is null or price <= $max_price)
        and ($max_mileage is null or mileage <= $max_mileage)
      order by price - predicted_price2
      limit $best_deal_size
    SQL

    def _analyze_car_all(db, options, output = $stdout)
      items = []
      models = db.query(LIST_MODELS_SQL)
      models.each do |model|
        items.concat analyze_car_model(db, model[0], options, output) if Integer(model[2]) > 10
      end
      items
    end

    def analyze_car_model(db, model, options, output = $stdout)
      s = Struct.new(:mileage, :issuance_date, :price)
      sample_items = db.query(ANALYZE_SQL, model: model).map do |item|
        s.new(Integer(item[0]), item[1].to_date, Float(item[2]))
      end
      analysis = Analysis.new(sample_items)
      output.puts "Analysis for #{model} based on #{sample_items.size} items"
      analysis.linear_regression
      analysis.explain(output)
      analysis.explain2(output)

      # Find the best deals, i.e. the lowest price compared to the prediction
      output.puts "Best #{options[:best_deal_size]} deals for #{model}"
      records = db.query(BEST_DEALS_SQL, model: model, base_price: analysis.base_price,
                                         cost_per_kms: analysis.cost_per_kms, cost_per_day: analysis.cost_per_day,
                                         max_price: options[:max_price], max_mileage: options[:max_mileage],
                                         best_deal_size: options.fetch(:best_deal_size))
      items = records.map do |rec|
        BEST_DEALS_ITEMS.new(*rec)
      end

      items.each do |item|
        output.puts item.print(analysis)
      end
      items
    end

    def refresh(db, params, crawler: HTTPCrawler.new, only_newer: true)
      # find latest index_date in database
      from_index_date = nil
      if options.fetch(:only_newer, true)
        from_index_date = db.query("select MAX(raw->>'index_date') from raw_items where search_params = ?",
                                   params).first&.first
      end

      if from_index_date
        puts "#{params}: Fetching only-newer items from index_date #{from_index_date}"
      else
        puts "#{params}: Fetching all items"
      end
      recherche = crawler.recherche(params, from_index_date: from_index_date)
      recherche.each_with_index do |page, page_id|
        puts "Fetching page #{page_id}"
        items = page.items
        items = items.select { |item| item['index_date'] > from_index_date } if from_index_date
        puts "Insert #{items.size} items in database"
        db.add_raw_items('list_id', params, items)
      end
    rescue HTTPCrawler::Error => e
      puts "Error while fetching #{params}: #{e}"
    end
  end
end
