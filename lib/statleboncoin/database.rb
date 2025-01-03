require 'duckdb'
require 'forwardable'
require 'json'

module Statleboncoin
  class Database
    extend Forwardable
    def_delegator :@conn, :query

    CAR_ITEM_VIEW_SQL = <<~SQL
      with json_parsed as (
        select json_transform(raw,
          '{
            "url": "VARCHAR",
            "index_date": "TIMESTAMP",
            "price_cents": "NUMERIC",
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
            "attributes": [
              {
                "key": "VARCHAR",
                "value": "VARCHAR"
              }
            ]
          }') as r
        from raw_items),
      json_parsed_attributes_pivoted as (
        select
          r.url as url,
          r.index_date as index_date,
          r.price_cents as price_cents,
          r.location as location,
          map_from_entries(r.attributes) as attributes
        from json_parsed
      )
      select
        url,
        index_date,
        cast(price_cents / 100 as integer) as price,
        attributes['brand'][1] as brand,
        attributes['model'][1] as model,
        cast(attributes['regdate'][1] as integer) as reg_year,
        if(attributes['issuance_date'][1] is not null, strptime(attributes['issuance_date'][1], '%m/%Y'), strptime(attributes['regdate'][1], '%Y')) as issuance_date,
        cast(attributes['mileage'][1] as integer) as mileage,
        attributes['is_import'][1] as is_import,
        cast(attributes['horse_power'][1] as integer) as horse_power,
        cast(attributes['horse_power_din'][1] as integer) as horse_power_din,
        attributes['vehicle_damage'][1] as vehicle_damage,
        attributes['car_contract'][1] as car_contract,
        location
      from json_parsed_attributes_pivoted;
    SQL

    def initialize(database_file = 'statleboncoin.duckdb')
      raise ArgumentError, 'Database file must end with .duckdb' unless database_file.end_with?('.duckdb')

      @db = DuckDB::Database.open database_file
      @conn = @db.connect
      @conn.query('INSTALL spatial')
      @conn.query('LOAD spatial')
      @conn.query('CREATE TABLE IF NOT EXISTS raw_items (id TEXT PRIMARY KEY, updated_at timestamp not null, search_params TEXT, raw JSON)')
      @conn.query('CREATE TABLE IF NOT EXISTS raw_items_archive (id TEXT PRIMARY KEY, updated_at timestamp not null, search_params TEXT, raw JSON)')
      @conn.query("CREATE OR REPLACE TABLE car_items AS #{CAR_ITEM_VIEW_SQL}")
      @conn.query('CREATE TABLE IF NOT EXISTS sent_urls (url TEXT PRIMARY KEY, sent_at TIMESTAMP)')
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
