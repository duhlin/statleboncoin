TestRawItems = Struct.new(:mileage, :issuance_date, :price)

RSpec.describe Statleboncoin::Analysis do
  let(:item_a) { TestRawItems.new(10_000, Date.new(2020, 1, 1), 15_000) }
  let(:item_b) { TestRawItems.new(20_000, Date.new(2020, 1, 1), 13_000) }
  let(:item_c) { TestRawItems.new(30_000, Date.new(2020, 1, 1), 11_000) }
  let(:item_d) { TestRawItems.new(10_000, Date.new(2021, 1, 1), 20_000) }
  let(:items) { [item_a, item_b, item_c, item_d] }
  it 'can compute a linear regression' do
    analysis = Statleboncoin::Analysis.new(items)
    analysis.linear_regression
    expect(analysis.r_squared).to be_within(0.01).of(1.0)
    items.each do |item|
      expect(analysis.predict_price(item)).to be_within(0.01).of(item.price)
    end
  end
end
