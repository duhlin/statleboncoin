RSpec.describe Statleboncoin::CarItem do
  let(:fixture) { JSON.parse(File.read("spec/fixtures/raw_item.json")) }
  it "can be initialized from json" do
    raw_item = Statleboncoin::CarItem.from_json(fixture.to_json)
    expect(raw_item.url).to eq("https://www.leboncoin.fr/ad/voitures/2395566521")
    expect(raw_item.index_date).to eq("2024-09-16 22:03:14")
    expect(raw_item.price).to eq(9300.0)
    expect(raw_item.brand).to eq("Renault")
    expect(raw_item.model).to eq("Zoe")
    expect(raw_item.issuance_date).to eq(Date.new(2016, 6))
    expect(raw_item.reg_year).to eq(2016)
    expect(raw_item.mileage).to eq(40_443)
    expect(raw_item.is_import).to eq(false)
    expect(raw_item.horse_power_din).to eq(88)
    expect(raw_item.vehicle_damage).to eq("unknown")
    expect(raw_item.car_contract).to eq(false)
  end
end
