RSpec.describe Statleboncoin::HTTPCrawler do
  let(:params) { "category=2&text=e208&fuel=4" }
  let(:crawler) { Statleboncoin::HTTPCrawler.new }
  let(:recherche) { crawler.recherche(params) }
  let(:recherche_first_page) { recherche.first }
  let(:first_page_items) { recherche_first_page.items }
  it "can get a page" do
    res = crawler.get "/recherche?#{params}"
    expect(res.status).to eq 200
  end

  it "can parse a 'recherche'" do
    expect(recherche).to be_an Enumerator
    expect(recherche_first_page).to be_a Statleboncoin::HTTPCrawler::RecherchePage
  end

  it "can list items" do
    expect(first_page_items).to be_an Array
    expect(first_page_items).not_to be_empty
  end

  it "can iterate over pages" do
    expect(recherche.to_a.size).to be > 1
  end

  it "can iterate over pages, returning only items greater than from_index_date" do
    from_index_date = first_page_items.last["index_date"]
    expect(crawler.recherche(params, from_index_date: from_index_date).count).to eq(2)
  end

  it "works because items are sorted by index_date descending" do
    index_dates = first_page_items.map { |item| item["index_date"] }
    expect(index_dates).to eq index_dates.sort.reverse
  end
end
