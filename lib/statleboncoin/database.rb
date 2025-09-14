require 'duckdb'
require 'forwardable'
require 'json'

module Statleboncoin
  class Database
    extend Forwardable
    def_delegator :@conn, :query

    def car_item_view_sql(table)
      sql = <<~SQL
      with json_parsed as (
        select
          id,
          search_params,
          json_transform(raw,
          '{
            "category_id": "INTEGER",
            "category_name": "VARCHAR",
            "url": "VARCHAR",
            "index_date": "TIMESTAMP",
            "first_publication_date": "TIMESTAMP",
            "price_cents": "NUMERIC",
            "subject": "VARCHAR",
            "location": {
              "country_id": "VARCHAR",
              "region_id": "INTEGER",
              "region_name": "VARCHAR",
              "department_id": "INTEGER",
              "department_name": "VARCHAR",
              "city_label": "VARCHAR",
              "city": "VARCHAR",
              "zipcode": "VARCHAR",
              "lat": "NUMERIC",
              "lng": "NUMERIC"
            },
            "images": {
              "thumb_url": "VARCHAR",
              "small_url": "VARCHAR"
            },
            "attributes": [
              {
                "key": "VARCHAR",
                "value": "VARCHAR"
              }
            ]
          }') as r
        from #{table}),
      json_parsed_attributes_pivoted as (
        select
          id,
          search_params,
          r.category_id as category_id,
          r.category_name as category_name,
          r.url as url,
          r.index_date as index_date,
          r.first_publication_date as first_publication_date,
          r.price_cents as price_cents,
          r.location as location,
          r.images as images,
          r.subject as subject,
          map_from_entries(r.attributes) as attributes
        from json_parsed
      )
      select
        id,
        category_id,
        category_name,
        search_params,
        url,
        index_date,
        first_publication_date,
        subject,
        cast(price_cents / 100 as integer) as price,
        coalesce(attributes['u_car_brand'], attributes['u_utility_brand']) as brand,
        coalesce(attributes['u_car_model'], attributes['u_utility_model']) as model,
        coalesce(attributes['u_car_finition'], attributes['u_utility_finition']) as finition,
        cast(attributes['regdate'] as integer) as reg_year,
        if(attributes['issuance_date'] is not null, strptime(attributes['issuance_date'], '%m/%Y'), strptime(attributes['regdate'], '%Y')) as issuance_date,
        cast(attributes['mileage'] as integer) as mileage,
        attributes['is_import'] as is_import,
        cast(attributes['horse_power'] as integer) as horse_power,
        cast(attributes['horse_power_din'] as integer) as horse_power_din,
        attributes['vehicle_damage'] as vehicle_damage,
        attributes['car_contract'] as car_contract,
        attributes['seats'] as seats,
        location,
        images
      from json_parsed_attributes_pivoted;
      SQL
      sql
    end

    def initialize(database_file = 'statleboncoin.duckdb')
      raise ArgumentError, 'Database file must end with .duckdb' unless database_file.end_with?('.duckdb')

      @database_file = database_file
      @db = DuckDB::Database.open database_file
      @conn = @db.connect
      @conn.query('INSTALL spatial')
      @conn.query('LOAD spatial')
      @conn.query('CREATE TABLE IF NOT EXISTS raw_items (id TEXT PRIMARY KEY, updated_at timestamp not null, search_params TEXT, raw JSON)')
      @conn.query('CREATE TABLE IF NOT EXISTS raw_items_archive (id TEXT PRIMARY KEY, updated_at timestamp not null, search_params TEXT, raw JSON)')
      @conn.query("CREATE OR REPLACE VIEW car_items AS #{car_item_view_sql('raw_items')}")
      @conn.query("CREATE OR REPLACE TABLE car_items_archive AS #{car_item_view_sql('raw_items_archive')}")
      @conn.query("CREATE OR REPLACE VIEW all_car_items AS select false as archived, * from car_items union all select true as archived, * from car_items_archive")
      @conn.query('CREATE TABLE IF NOT EXISTS sent_urls (url TEXT PRIMARY KEY, sent_at TIMESTAMP)')
    end

    def release
      @conn.disconnect
      @db.close
      yield
      @db = DuckDB::Database.open @database_file
      @conn = @db.connect
    end

    def archive_raw_items
      # create or replace is very slow, so use insert and update
      # @conn.query('INSERT OR REPLACE INTO raw_items_archive(id, updated_at, search_params, raw) SELECT id, now(), search_params, raw FROM raw_items')
      @conn.query('BEGIN TRANSACTION')
      @conn.query('INSERT INTO raw_items_archive(id, updated_at, search_params, raw) SELECT id, updated_at, search_params, raw FROM raw_items ANTI JOIN raw_items_archive USING (id)')
      @conn.query('UPDATE raw_items_archive SET updated_at = raw_items.updated_at, search_params = raw_items.search_params, raw = raw_items.raw FROM raw_items WHERE raw_items_archive.id = raw_items.id')
      @conn.query('COMMIT')
      @conn.query('DROP TABLE raw_items')
    end

    def load_from_parquet(database_folder)
      @conn.query("COPY raw_items from '#{database_folder}/raw_items.parquet' (FORMAT 'parquet')")
    end

    def save_to_parquet(database_folder)
      @conn.query("EXPORT DATABASE '#{database_folder}' (FORMAT PARQUET, CODEC 'zstd')")
    end

    def close
      @conn.disconnect
      @db.close
    end

    def add_raw_items(key_attribute, search_params, items)
      append_raw_items(key_attribute, search_params, items)
    rescue DuckDB::Error
      insert_raw_items(key_attribute, search_params, items)
    end

    def mark_url_as_sent(urls)
      appender = @conn.appender('sent_urls')
      now = Time.now
      urls.each do |u|
        appender.begin_row
        appender.append(u)
        appender.append(now)
        appender.end_row
      end
      appender.flush
    end

    private

    def append_raw_items(key_attribute, search_params, items)
      appender = @conn.appender('raw_items')
      t = Time.now
      items.each do |item|
        appender.begin_row
        appender.append(item.fetch(key_attribute))
        appender.append(t)
        appender.append(search_params)
        appender.append(item.to_json)
        appender.end_row
      end
      appender.flush
    end

    INSERT_RAW_ITEMS_SQL = <<~SQL
      INSERT OR REPLACE INTO raw_items(id, updated_at, search_params, raw)
      VALUES (?, ?, ?, ?)
    SQL
    def insert_raw_items(key_attribute, search_params, items)
      t = Time.now
      items.each do |item|
        @conn.query(INSERT_RAW_ITEMS_SQL, item.fetch(key_attribute), t, search_params, item.to_json)
      end
    end
  end
end
