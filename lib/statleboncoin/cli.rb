require "thor"

module Statleboncoin
  class CLI < Thor
    BEST_DEAL_SIZE = 20
    SAMPLE_SIZE = 200

    desc "recherche PARAMS",
         "Retrieve items from https://www.leboncoin.fr/recherche?PARAMS and store them in a database"
    method_options "only-newer" => :boolean
    def recherche(params, database_file = "statleboncoin.duckdb")
      puts "recherche #{params} #{options}"
      puts "Initializing database #{database_file}"
      db = Database.new(database_file)

      begin
        refresh(db, params, only_newer: options.fetch("only-newer", true))
      ensure
        db.close
      end
    end

    desc "save_to_parquet DATABASE_FOLDER",
         "Export the database to DATABASE_FOLDER in parquet format"
    def save_to_parquet(database_folder, database_file = "statleboncoin.duckdb")
      puts "save_to_parquet #{database_folder} #{database_file}"
      db = Database.new(database_file)
      db.save_to_parquet(database_folder)
      db.close
    end

    desc "load_from_parquet DATABASE_FOLDER",
         "Load the database from DATABASE_FOLDER in parquet format"
    def load_from_parquet(database_folder, database_file = "statleboncoin.duckdb")
      puts "load_from_parquet #{database_folder} #{database_file}"
      db = Database.new(database_file)
      db.load_from_parquet(database_folder)
      db.close
    end

    desc "refresh_all",
         "Retrieve new items for all existing search in the database"
    def refresh_all(database_file = "statleboncoin.duckdb")
      db = Database.new(database_file)
      begin
        crawler = HTTPCrawler.new
        db.query("select DISTINCT search_params from raw_items").each do |params|
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

    desc "list_models",
         "List the models in the database"
    def list_models(database_file = "statleboncoin.duckdb")
      db = Database.new(database_file)
      begin
        models = db.query(LIST_MODELS_SQL)
        model_max_size = models.map(&:first).map { |model| model&.size || 0 }.max
        puts "#{"Model".ljust(model_max_size)} | Items | Excluding damaged and contract cars"
        models.each do |model, count, effective_count|
          puts "#{(model || "").ljust(model_max_size)} | #{count.to_s.rjust(5)} | #{effective_count.to_s.rjust(5)}"
        end
      ensure
        db.close
      end
    end

    desc "analyze_car MODEL",
         "Return the best deals for a given FILTER"
    option :best_deal_size, type: :numeric, default: BEST_DEAL_SIZE
    option :max_price, type: :numeric
    option :max_mileage, type: :numeric
    option :max_age, type: :numeric
    def analyze_car(filter, database_file = "statleboncoin.duckdb")
      db = Database.new(database_file)
      begin
        analyze_car_model(db, filter, options)
      ensure
        db.close
      end
    end

    desc "analyze_car_all",
         "Return the best deals for all models"
    option :best_deal_size, type: :numeric, default: BEST_DEAL_SIZE
    option :max_price, type: :numeric
    option :max_mileage, type: :numeric
    option :max_age, type: :numeric
    def analyze_car_all(database_file = "statleboncoin.duckdb")
      db = Database.new(database_file)
      begin
        models = db.query(LIST_MODELS_SQL)
        models.each do |model|
          analyze_car_model(db, model[0], options) if Integer(model[2]) > 10
        end
      end
    end

    private

    ANALYZE_SQL = <<~SQL
      select * from (
        select distinct mileage, issuance_date, price -- use distinct because some items are duplicated
        from car_items
        where coalesce(model, '') = coalesce($model, '') and coalesce(vehicle_damage, '') != 'damaged' and coalesce(car_contract, '') != '1'
      ) s using sample #{SAMPLE_SIZE}
    SQL

    BEST_DEALS_SQL = <<~SQL
      select
        distinct * -- use distinct because some items are duplicated
      from car_items
      where coalesce(model, '') = coalesce($model, '')
        and coalesce(vehicle_damage, '') != 'damaged'
        and coalesce(car_contract, '') != '1'
        and ($max_price is null or price <= $max_price)
        and ($max_mileage is null or mileage <= $max_mileage)
      order by abs(price - ($base_price + $cost_per_kms * mileage + $cost_per_day * date_diff('day', issuance_date, current_date())))
      limit $best_deal_size
    SQL

    def analyze_car_model(db, model, options)
      s = Struct.new(:mileage, :issuance_date, :price)
      items = db.query(ANALYZE_SQL, model: model).map do |item|
        s.new(Integer(item[0]), item[1].to_date, Float(item[2]))
      end
      analysis = Analysis.new(items)
      puts "Analysis for #{model} based on #{items.size} items"
      analysis.linear_regression
      analysis.explain

      # Find the best deals
      # 1. Find the items with the lowest price compared to the prediction
      items = db.query(BEST_DEALS_SQL, model: model, base_price: analysis.base_price,
                                       cost_per_kms: analysis.cost_per_kms, cost_per_day: analysis.cost_per_day,
                                       max_price: options[:max_price], max_mileage: options[:max_mileage],
                                       best_deal_size: options.fetch(:best_deal_size))
      puts "Best #{options[:best_deal_size]} deals for #{model}"
      items.each do |item|
        puts "#{item}"
      end
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
        items = items.select { |item| item["index_date"] > from_index_date } if from_index_date
        puts "Insert #{items.size} items in database"
        db.add_raw_items("list_id", params, items)
      end
    end
  end
end
