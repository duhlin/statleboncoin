require 'thor'

module Statleboncoin
  class CLI < Thor
    def self.exit_on_failure?
      true
    end
    BEST_DEAL_SIZE = 20
    SAMPLE_SIZE = 200

    desc 'recherche PARAMS',
         'Retrieve items from https://www.leboncoin.fr/recherche?PARAMS and store them in a database'
    method_options 'only_newer' => :boolean
    def recherche(params, database_file = 'statleboncoin.duckdb')
      puts "recherche #{params} #{options}"
      puts "Initializing database #{database_file}"
      db = Database.new(database_file)
      begin
        refresh(db, params, only_newer: options.fetch('only_newer', true))
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
    option :only_newer, type: :boolean, default: true
    def refresh_all(database_file = 'statleboncoin.duckdb')
      db = Database.new(database_file)
      begin
        crawler = HTTPCrawler.new
        db.query('with s as (select distinct search_params from raw_items union select distinct search_params from raw_items_archive) select * from s order by search_params').each do |params|
          refresh(db, params.first, crawler: crawler, only_newer: options[:only_newer])
        end
      ensure
        db.close
      end
    end

    LIST_MODELS_SQL = <<~SQL
      select
        model,
        brand,
        category_id,
        count(*),
        count_if(coalesce(vehicle_damage, '') != 'damaged' and coalesce(car_contract, '') != '1')
      from car_items
      group by all
      order by model
    SQL

    def recherche_url(category_id, brand, model)
      case(category_id)
      when 2
        "category=2&u_car_brand=#{brand}&u_car_model=#{model}&fuel=4"
      when 5
        "category=5&u_utility_brand=#{brand}&u_utility_model=#{model}&fuel=4"
      end
    end

    desc 'list_models',
         'List the models in the database'
    def list_models(database_file = 'statleboncoin.duckdb')
      db = Database.new(database_file)
      begin
        models = db.query(LIST_MODELS_SQL).to_a
        model_max_size = models.map(&:first).map { |model| model&.size || 0 }.max
        puts "#{'Model'.ljust(model_max_size)} | Items | Excluding damaged and contract cars"
        models.each do |model, brand, category_id, count, effective_count|
          puts "#{(model || '').ljust(model_max_size)} | #{count.to_s.rjust(5)} | #{effective_count.to_s.rjust(5)} | #{recherche_url(category_id, brand, model)}"
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
    option :max_distance, type: :numeric
    option :my_lat, type: :numeric
    option :my_lng, type: :numeric
    option :horse_power_din, type: :numeric
    def analyze_car(model, database_file = 'statleboncoin.duckdb')
      db = Database.new(database_file)
      begin
        analyze_car_model(db, model, options, $stdout)
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
    option :max_distance, type: :numeric
    option :my_lat, type: :numeric
    option :my_lng, type: :numeric
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
    option :max_distance, type: :numeric
    option :my_lat, type: :numeric
    option :my_lng, type: :numeric
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

        # refresh the python analysis
        db.release do
          system('./export_notebook.sh', chdir: 'modeling')
        end

        # force a message_id so that emails are threaded
        Mail.deliver do
          to mail_to
          from mail_from
          message_id 'c38f15ca-cfc5-4f30-9199-07f079ea62f8@statleboncoin'
          subject 'Statleboncoin best deals'
          body output.string
          add_file 'modeling/notebooks/car_price_pca_analysis.html'
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
        and ($horse_power_din is null or horse_power_din = $horse_power_din)
      ) s using sample #{SAMPLE_SIZE}
    SQL

    BEST_DEALS_COLUMNS = {
      url: 'car_items.url',
      brand: 'brand',
      subject: 'subject',
      model: 'car_items.model',
      mileage: 'mileage',
      issuance_date: 'issuance_date',
      first_publication_date: 'first_publication_date',
      distance: 'st_distance_spheroid(ST_Point(location.lat, location.lng), ST_Point(my_pos.lat, my_pos.lng))/1000 as distance',
      price: 'price',
      seats: 'seats',
      age_in_days: 'date_diff(\'day\', issuance_date, current_date()) as age_in_days',
      regression_predicted_price: "greatest(1, (analysis.base_price + analysis.cost_per_kms * mileage + analysis.cost_per_day * age_in_days)) as regression_predicted_price",
      regression_discount: "(regression_predicted_price - price)/regression_predicted_price as regression_discount",
      my_predicted_price: "greatest(1, analysis.base_price * (1 -  mileage / #{Analysis::HOME_PREDICT_MAX_MILEAGE} - age_in_days/#{Analysis::HOME_PREDICT_MAX_AGE_DAYS})) as my_predicted_price",
      my_discount: "(my_predicted_price - price)/my_predicted_price as my_discount",
      sent_at: 'sent_at'
    }
    BEST_DEALS_ITEMS = Struct.new(*BEST_DEALS_COLUMNS.keys) do
      def print(analysis)
        my_discount_s = regression_discount_s = ' ' * 4
        if analysis
          # check_predicted_price = [analysis.predict_price(self), 0].max
          # if (check_predicted_price - regression_predicted_price).abs > 100
          #    raise "unexpected diff: check_predicted_price=#{check_predicted_price} predicted_price=#{regression_predicted_price}"
          # end
        
          regression_discount_s = (regression_discount * 100).to_i.to_s.rjust(4)
          my_discount_s = (my_discount * 100).to_i.to_s.rjust(4)
        end
        mileage_s = mileage.to_s.rjust(7)
        price_s = price.to_s.rjust(5)
        distance_s = distance.to_i.to_s.rjust(3)
        new = sent_at.nil? ? ' **NEW**' : '       '
        "#{brand} - #{model&.delete_prefix("#{brand}_")}, #{mileage_s} kms, #{distance_s} kms away, #{issuance_date.strftime('%Y/%m')}: #{price_s} € (reg=#{regression_discount_s} %,  my=#{my_discount_s} %) #{url}#{new} #{subject}"
      end
    end

    CREATE_TABLE_MY_POSITION = <<~SQL
      create or replace table my_position
      AS select
        $my_lat as lat,
        $my_lng as lng
    SQL

    CREATE_VIEW_ANALYZED_CARS = <<~SQL
      create or replace view analyzed_cars
      as
      select
        car_items.id,
        car_items.vehicle_damage,
        car_items.car_contract,
        car_items.horse_power_din,
        analysis.base_price,
        analysis.cost_per_kms,
        analysis.cost_per_day,
        #{BEST_DEALS_COLUMNS.values.join(', ')}
      from car_items
      left outer join car_analysis_results as analysis using (model)
      cross join my_position as my_pos
      left outer join sent_urls using (url)
    SQL

    CREATE_TABLE_CAR_ANALYSIS_RESULTS = <<~SQL
      create table if not exists car_analysis_results(
        model text primary key,
        base_price numeric not null,
        cost_per_kms numeric not null,
        cost_per_day numeric not null
      )
    SQL

    INSERT_CAR_ANALYSIS_RESULTS = <<~SQL
      insert or replace into car_analysis_results(model, base_price, cost_per_kms, cost_per_day)
      select
        $model as model,
        $base_price as base_price,
        $cost_per_kms as cost_per_kms,
        $cost_per_day as cost_per_day
    SQL

    BEST_DEALS_SQL = <<~SQL
      select #{BEST_DEALS_COLUMNS.keys.join(", ")} from analyzed_cars
      where coalesce(model, '') = coalesce($model, '')
        and coalesce(vehicle_damage, '') != 'damaged'
        and coalesce(car_contract, '') != '1'
        and price > #{ANALYZE_MIN_PRICE}
        and ($max_price is null or price <= $max_price)
        and ($max_mileage is null or mileage <= $max_mileage)
        and ($max_age is null or date_diff('year', issuance_date, current_date()) <= $max_age)
        and ($max_distance is null or distance <= $max_distance)
        and ($horse_power_din is null or horse_power_din = $horse_power_din)
      order by my_discount desc
      limit $best_deal_size
    SQL

    def _analyze_car_all(db, options, output = $stdout)
      items = []
      models = db.query(LIST_MODELS_SQL)
      models.each do |model|
        items.concat analyze_car_model(db, model[0], options, output) # if Integer(model[2]) > 10
      end
      items
    end

    def analyze_car_model(db, model, options, output = $stdout)
      s = Struct.new(:mileage, :issuance_date, :price)
      sample_items = db.query(ANALYZE_SQL, model: model, horse_power_din: options[:horse_power_din]).map do |item|
        s.new(Integer(item[0]), item[1].to_date, Float(item[2]))
      end
      if sample_items.empty?
        output.puts "No items for #{model}"
        return []
      end

      analysis = Analysis.new(sample_items)
      output.puts "Analysis for #{model} based on #{sample_items.size} items"
      begin
        analysis.linear_regression
        analysis.explain(output)
        analysis.explain2(output)
      rescue StandardError => e
        output.puts "Error while analyzing #{model}: #{e}"
        analysis = nil
      end

      # Find the best deals, i.e. the lowest price compared to the prediction
      output.puts "Best #{options[:best_deal_size]} deals for #{model}"
      
      # create required base tables
      db.query(CREATE_TABLE_MY_POSITION, my_lat: options[:my_lat], my_lng: options[:my_lng])
      db.query(CREATE_TABLE_CAR_ANALYSIS_RESULTS)
      begin
        db.query(INSERT_CAR_ANALYSIS_RESULTS,
                model: model,
                base_price: analysis&.base_price,
                cost_per_kms: analysis&.cost_per_kms,
                cost_per_day: analysis&.cost_per_day) if analysis
      rescue DuckDB::Error => e
        output.puts "Error while inserting car analysis results for #{model}: #{e}"
      end
      db.query(CREATE_VIEW_ANALYZED_CARS)
      
      records = db.query(
        BEST_DEALS_SQL,
        model: model,
        max_price: options[:max_price],
        max_mileage: options[:max_mileage],
        max_age: options[:max_age],
        best_deal_size: options.fetch(:best_deal_size),
        max_distance: options[:max_distance],
        horse_power_din: options[:horse_power_din]
      )
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
      print "#{params}: "
      from_index_date = nil
      if only_newer
        from_index_date = db.query("select MAX(raw->>'index_date') from raw_items where search_params = ?",
                                  params).first&.first
      end

      if from_index_date
        puts "only-newer items from index_date #{from_index_date}"
      else
        puts "all items"
      end

      recherche = crawler.recherche(params + "&sort=time&order=desc", from_index_date: from_index_date)
      recherche.each_with_index do |page, page_id|
        print "  page #{page_id.to_s.rjust(2)}, "
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
