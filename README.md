# Statleboncoin

Ruby tooling and a small Python modeling stack for collecting [Le Bon Coin](https://www.leboncoin.fr) vehicle listings, storing them in [DuckDB](https://duckdb.org), and ranking listings against simple price models.

## What it does

- **Crawl** search result pages and read embedded `__NEXT_DATA__` JSON (`HTTPCrawler`).
- **Persist** raw ads in DuckDB (`raw_items` / `raw_items_archive`), expose normalized **`car_items`** views (cars category `2` and utilitaires category `5`), optional Parquet import/export.
- **Analyze** per-model linear regression on mileage and age, then surface “best deals” with optional filters (price, mileage, distance from a lat/lng, and more) via Thor CLI commands.
- **Modeling** (`modeling/`): Jupyter notebooks (PCA, Bayesian workflows, fleet-focused analysis) and Python utilities; notebooks can be exported to HTML with `export_notebook.sh`.

Upstream HTML structure and anti-bot measures can change at any time; scraping may break without updates.

## Requirements

- Ruby **≥ 3.0** (see `statleboncoin.gemspec`).
- DuckDB Ruby gem (pulled in via Bundler).
- For notebooks: Python **3** with a virtualenv under `modeling/.venv` and Jupyter / nbconvert installed.

## Installation

Clone the repository and install dependencies:

```bash
git clone https://github.com/duhlin/statleboncoin.git
cd statleboncoin
bin/setup   # or: bundle install
```

The gem is not configured for RubyGems publication yet (`gemspec` still contains TODO placeholders). To use it from another project, add a **git** source or `path:` dependency in your `Gemfile`.

### DuckDB C library (`duckdb` Ruby gem)

The **`duckdb`** gem ships a native extension that links against **libduckdb** (C API). Recent gem releases expect **DuckDB ≥ 1.4** (for example **1.5.x** gems match **1.5.x** C libraries). If `bundle install` fails while compiling `duckdb`, install headers and `libduckdb.so`, then try again.

**Option A — vendored copy in this repo (no root privileges)**

The `vendor/duckdb/` tree is gitignored. Download the official Linux amd64 bundle for the [release you want](https://github.com/duckdb/duckdb/releases) (below uses **v1.5.2**), unpack headers and the shared library, point Bundler at them, then install:

```bash
mkdir -p vendor/duckdb/include vendor/duckdb/lib
curl -fsSL -o /tmp/libduckdb.zip https://github.com/duckdb/duckdb/releases/download/v1.5.2/libduckdb-linux-amd64.zip
unzip -j /tmp/libduckdb.zip libduckdb.so -d vendor/duckdb/lib
unzip -j /tmp/libduckdb.zip duckdb.h duckdb.hpp -d vendor/duckdb/include
bundle config set --local build.duckdb "--with-duckdb-include=$(pwd)/vendor/duckdb/include --with-duckdb-lib=$(pwd)/vendor/duckdb/lib"
bundle install
```

**Option B — system install**

Unpack the same zip (or install a matching distribution package), copy `duckdb.h` / `duckdb.hpp` and `libduckdb.so` into e.g. `/usr/local/include` and `/usr/local/lib`, then refresh the dynamic linker cache:

```bash
sudo ldconfig
```

After that, `bundle install` should find the library without `build.duckdb`. Remove any local `build.duckdb` entry from `.bundle/config` if you previously used Option A.

## CLI usage

Run via Bundler:

```bash
bundle exec bin/statleboncoin help
```

Typical commands:

| Command | Purpose |
|--------|---------|
| `recherche PARAMS` | Fetch `/recherche?PARAMS`, append sorted pages, store rows (optional `--only-newer`). |
| `refresh_all` | Re-run every distinct `search_params` already in the DB. |
| `refresh_all_models` | For each distinct `(brand, model, category_id)` in live + archive data, rebuild search params and refresh (options: `--only-newer`, `--ludospace`). |
| `list_models` | Counts per model plus query-string fragments for re-fetching. |
| `analyze_car MODEL` / `analyze_car_all` | Regression + best-deal listing with filters (`--max-price`, `--my-lat`, `--my-lng`, …). |
| `archive_raw_items` | Move old raw rows to archive storage. |
| `save_to_parquet` / `load_from_parquet` | Folder-level DuckDB backup helpers. |
| `send_email` | SMTP digest of deals; refreshes `car_price_pca_analysis` notebook HTML before sending (requires SMTP options). |

Default database path is **`statleboncoin.duckdb`** in the current working directory.

## Modeling directory

- **`modeling/notebooks/`** — analysis notebooks and exported HTML.
- **`modeling/export_notebook.sh`** — runs `jupyter nbconvert --execute` on a given `.ipynb` and tweaks link styling in the HTML output.
- **`modeling/src/`** — Python package layout for training utilities and tests (`modeling/tests/`).

Example export:

```bash
cd modeling
./export_notebook.sh notebooks/car_price_pca_analysis.ipynb
```

Configuration such as DuckDB path, ignored URLs, and analysis thresholds lives in `modeling/src/utils/config.py`.

## Development

```bash
bundle exec rake spec    # RSpec
bundle exec bin/console  # IRB with the gem loaded
```

## Contributing

Issues and pull requests are welcome at https://github.com/duhlin/statleboncoin .

## License

MIT — see [LICENSE.txt](LICENSE.txt).

## Code of conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
