RSpec.describe Statleboncoin::Database do
  subject { Statleboncoin::Database.new(nil) }
  let(:item1) { { href: 'href1', raw: { a: 1 } } }
  let(:item2) { { href: 'href2', raw: { b: 2 } } }

  it 'can be initialized and closed' do
    expect { subject }.not_to raise_error
    expect { subject.close }.not_to raise_error
  end

  it 'can save and load to parquet' do
    subject.add_raw_items(:href, 'params', [item1, item2])
    subject.save_to_parquet('test_database')

    new_db = Statleboncoin::Database.new(nil)
    new_db.load_from_parquet('test_database')
    expect(new_db.query('select count(*) from raw_items').to_a).to eq([[2]])
    expect(new_db.query('select id from raw_items').map(&:first)).to eq(%w[href1 href2])
  end
end
