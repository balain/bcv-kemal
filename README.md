# bcv-kemal

Bible search and display web app

Built using Crystal (programming language), Kemal (web framework), SQLite (database)

## Features
- Interlinear search results
- Full text search: English, Hebrew, and Greek
- Provide your own Bible content
- No server required - uses sqlite database (local)
- Good performance - compiled code
- Query Greek and Hebrew by root/lemma
- Search for works with specific part of speech
- Strong's definitions - both popup and inline
- See difference, union, and intersection across prior search results
- Uses Bootstrap 5

## Installation

1. Install Crystal - https://crystal-lang.org
1. Install Kemal - https://kemalcr.com
1. Clone this repo
1. Rename `.env-example` to `.env` & update values to match your environment
1. Install dependencies - `shards install`
1. Install just - https://github.com/casey/just (optional)
1. Install watchexec - XYZ (optional)
1. Set up the database - instructions pending
1. Install Bible context server - c.f. https://github.com/balain/bible-context-server 

## Dependencies

### Crystal - required
- dotenv - https://github.com/drum445/dotenv
- sqlite3
- kemal

- Local copies of D3 (http://d3js.org/d3.v4.min.js)and Dimple (http://dimplejs.org/dist/dimple.v2.3.0.min.js)
  - Download and store in the bcv-kemal/public/js folder or update bcv_chart.cr to point to them by URL


### Optional
- just
- watchexec
- local bible-context-server instance (localhost) - for contextual popups

## Usage

1. Set up .env file with sensible defaults, including Bible Context Server (see below for details)

### Debug - Run
1. Run `just watch` (or `crystal run src/bcv-kemal.cr`)

### Production - Run
1. Run `just prod` (or `KEMAL_ENV=production crystal run src/bcv-kemal.cr --release -O3`)

### Production - Build
1. Run `just build-prod` (or `KEMAL_ENV=production crystal build src/bcv-kemal.cr -o bcv-kemal --release -O3`)

## Configuration

Set up a new `.env` file with sensible defaults

### Keys

- `DBFILE`: Path to SQLite database file
- `BASE_ENG_TRANS`: Base English translation to use for full text search

#### Bible Context Server
##### Ollama
- `CXT_OL_TIPPY_METHOD`: Method (http|https) of bible-context-server instance
- `CXT_OL_TIPPY_PORT`: Port of local bible-context-server instance
- `CXT_OL_TIPPY_PATH`: Path of local bible-context-server instance
- `CXT_OL_ICON`: Icon to use for context popup

##### Google Gemini
- `CXT_GGL_TIPPY_METHOD`: Method (http|https) of bible-context-server instance
- `CXT_GGL_TIPPY_PORT`: Port of local bible-context-server instance 
- `CXT_GGL_TIPPY_PATH`: Path of local bible-context-server instance 
- `CXT_GGL_ICON`: Icon to use for context popup

See `.env-example` for details

## TODO

- [ ] Change SQL to parameterized queries
- [ ] Document database schema
- [ ] Document .env fields
- [ ] Document content ETL
- [ ] Capture performance metrics

## Data Sources

### Text 
- English Bibles: https://openbible.com/texts.htm - several translations available
- Greek New Testament:
  - https://github.com/LogosBible/SBLGNT
  - https://github.com/STEPBible/STEPBible-Data
  - https://www.mrgreekgeek.com/2023/03/08/free-digital-greek-new-testaments/
  - https://codexsinaiticus.org/en/project/transcription_download.aspx 
- Hebrew Bible:
  - https://archive.org/details/original-hebrew-bible-a-free-paleo-hebrew-bible-including-all-books-of-the-old-t 
  - https://tanach.us/Pages/About.html 
- Strongs: https://github.com/STEPBible/STEPBible-Data/tree/master/Lexicons

### Converting USFX XML Files

#### Converter
- https://github.com/balain/usfx_to_tsv

#### Format
- https://github.com/biblenerd/awesome-bible-developer-resources?tab=readme-ov-file#usfx

## Warnings and Notices

- Queries are parameterized - avoids SQL injection
- Kemal server is http, not https
- There is no support for separate users or authentication - e.g. query history is shared across all clients
- Content: Abide by all copyrights and other content restrictions

## Development

TODO: Write development instructions here

## Contributing

1. Fork it (<https://github.com/balain/bcv-kemal/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request

## License

MIT

Copyright &copy; 2025

See [LICENSE](LICENSE) for full license content.

## Contributors

- [John](https://github.com/balain) - creator and maintainer
