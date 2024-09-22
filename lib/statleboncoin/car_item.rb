module Statleboncoin
  CarItemSchema = {
    url: 'text',
    index_date: 'timestamp',
    price: 'numeric',
    brand: 'varchar',
    model: 'varchar',
    issuance_date: 'timestamp',
    reg_year: 'integer',
    mileage: 'integer',
    is_import: 'boolean',
    horse_power: 'integer',
    horse_power_din: 'integer',
    vehicle_damage: 'boolean',
    car_contract: 'boolean'
  }

  CarItem = Struct.new(*CarItemSchema.keys, :raw_json) do
    def self.from_json(json)
      parsed_json = JSON.parse(json)
      url = parsed_json.fetch('url')
      index_date = parsed_json.fetch('index_date')
      price = Integer(parsed_json.fetch('price_cents')) / 100.0
      attributes = parsed_json.fetch('attributes').group_by { |attr| attr.fetch('key') }
      brand = attributes['brand']&.first&.fetch('value')
      model = attributes['model']&.first&.fetch('value')
      reg_year = Integer(attributes.fetch('regdate').first.fetch('value'))
      _issuance_date = attributes['issuance_date']&.first&.fetch('value')
      issuance_date = _issuance_date ? Date.strptime(_issuance_date, '%m/%Y') : Date.new(reg_year, 1, 1)
      mileage = Integer(attributes.fetch('mileage').first.fetch('value'))
      is_import = (attributes.fetch('is_import').first.fetch('value') == true)
      _horse_power = attributes['horse_power']&.first&.fetch('value')
      horse_power = _horse_power ? Integer(_horse_power) : nil
      _horse_power_din = attributes['horse_power_din']&.first&.fetch('value')
      horse_power_din = _horse_power_din ? Integer(_horse_power_din) : nil
      car_contract = attributes['car_contract']&.first&.fetch('value_label') == 'Oui'
      vehicle_damage = attributes['vehicle_damage']&.first&.fetch('value_label') || 'unknown'
      new(url, index_date, price, brand, model, issuance_date, reg_year, mileage, is_import, horse_power, horse_power_din,
          vehicle_damage, car_contract, json)
    rescue KeyError => e
      raise "Invalid JSON: #{parsed_json} #{e.message}"
    end
  end
end
