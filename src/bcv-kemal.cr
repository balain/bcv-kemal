# bcv-kemal.cr
#
# Main file for bcv-kemal
#

require "kemal"
require "sqlite3"
require "./bcv-db"
require "./bcv_chart"
require "./search_history"
require "./book_jumps"
#require "uuid" # For cookie IDs
require "dotenv"
require "kemal/log_handler"
require "uri" # For decoding Greek and Hebrew words in URLs

Dotenv.load

MAX_VISIBLE_HITS = 500

# Set up database
db = DB.open "sqlite3://" + ENV["DBFILE"]

Log.info { "Starting up..." } 

search_history = SearchHistory.new
book_jumps = BookJumps.new
book_filter = ""

get "/" do |env|
  # Display search form + Bible navigation page
  render "src/views/start.ecr"
end

get "/search" do |env|
  term = env.params.query["search_term"]?
  if term && term.size > 0
    trans = env.params.query["trans"] || "en"
    env.redirect "/search/#{trans}/#{term}"
  else
    "Search for a word: <form action='/search'><input type='text' name='search_term'><input type='hidden' name='trans' value='en'><input type='submit' value='Search'></form>"
  end
end

get "/search/eng/:word" do |env|
  env.redirect "/search/en/#{env.params.url["word"]}"
end

get "/search/" + ENV["BASE_ENG_TRANS"] + "/:word" do |env|
  env.redirect "/search/en/#{env.params.url["word"]}"
end

get "/search/:word" do |env|
  env.redirect "/search/en/#{env.params.url["word"]}"
end

SQL_FIELDS_COUNT = "SELECT nv.Book, count(*)"
SQL_FIELDS       = "SELECT nv.*,heb_verses.ContentProcessed as hebContent,  mv.ContentProcessed"
SQL_PRELUDE      = " from " + ENV["BASE_ENG_TRANS"] + "_verses as nv
left join morph_verses as mv on
  nv.Book = mv.Book and
  nv.Chapter = mv.Chapter and
  nv.Verse = mv.Verse
left join books as bks on
  nv.Book = bks.abbrev
left join heb_verses on
  bks.name = heb_verses.book AND
  nv.Chapter = heb_verses.chapter AND
  nv.Verse = heb_verses.verse
where nv.VerseNum in ("
SQL_COUNT_POSTLUDE = " GROUP BY nv.Book "
SQL_POSTLUDE  = " ORDER BY versenum"
BASIC_SELECT  = "SELECT VerseNum FROM " + ENV["BASE_ENG_TRANS"] + " WHERE WordCaps =?"
PHRASE_SELECT = "SELECT VerseNum FROM " + ENV["BASE_ENG_TRANS"] + "_verses WHERE Content like '%' || ? || '%'"

# Update the search history with new results
# ...unless they're already there
def append_if_new(sresults, search_history)
  i = 0
  while i < search_history.@search_results.size
    if search_history.@search_results[i].@word == sresults.@word && search_history.@search_results[i].@trans == sresults.@trans
      return false
    end
    i += 1
  end
  search_history.@search_results << sresults
  return true
end

# Set up the chart - either dimple or plotly
def set_chart_type(env, chart)
  if env.params.query["chart"]?
    if env.params.query["chart"] == "dimple"
      chart.set_chart_type(ChartType::Dimple)
    elsif env.params.query["chart"] == "plotly"
      chart.set_chart_type(ChartType::Plotly)
    else
      chart.set_chart_type(ChartType::Dimple)
    end
  end
end

# Greek: Find the root and replace the final word
def highlight_greek_by_lemma(lemma, gk)
  # TODO: Strip out the part of speech details, if present
  if gk.includes?(" word='" + lemma + "'")
    # Log.info { "Found content: " + gk }
    word_block = gk.match(/ word='#{lemma}' syn='[^']+'\>([^\<]+)<\/span>/i).try &.[1] || "ERROR"
    gk = gk.sub(">" + word_block + "</span>", "><B>" + word_block + "</B></span>")
  end
  gk
end

# English: Highlight all occurrences of the word
def highlight_english_word(word, eng)
  eng = eng.gsub(word, "<B>" + word + "</B>")
  eng = eng.gsub(word.capitalize, "<B>" + word.capitalize + "</B>")
  eng = eng.gsub(word.upcase, "<B>" + word.upcase + "</B>")
  eng = eng.gsub(word.downcase, "<B>" + word.downcase + "</B>")
  eng
end

# Placeholder - default to searching across all books
get "/search/en/:word" do |env|
  env.redirect "/search/en/#{env.params.url["word"]}/all"
end

get "/search/en/:word/:book" do |env|
  Log.info { "/search/en/#{env.params.url["word"]}/#{env.params.url["book"]} called..." }
  results_array = [] of String

  chart = BcvChart.new("Bible")
  
  results = ""
  result_count = 0
  term = env.params.url["word"]
  book_filter = env.params.url["book"] # Will be 'all' if no book specified

  show_all = env.params.query["show_all"]?
  trans = "en"
  pos = nil

  sresults = SearchResults.new(term, trans)

  set_chart_type(env, chart)

  # Query
  # Contains spaces? i.e. phrase search
  sql_count = SQL_FIELDS_COUNT + SQL_PRELUDE
  # #1: Count
  # #2: Hits
  sql = SQL_FIELDS + SQL_PRELUDE
  if term.includes?(" ")
    sql += PHRASE_SELECT
    sql_count += PHRASE_SELECT
  else
    sql += BASIC_SELECT
    sql_count += BASIC_SELECT
  end

  # Book specified?
  if book_filter != "all"
    sql += ") AND nv.book='#{book_filter}' "
  else
    sql += ") "
  end

  sql += SQL_POSTLUDE
  sql_count += ") #{SQL_COUNT_POSTLUDE} #{SQL_POSTLUDE}"

  if !show_all
    sql += " LIMIT #{DEFAULT_LIMIT}"
  end

  # Log.info { "SQL Count: #{sql_count}" }
  # Log.info { "SQL: #{sql}" }

  # Count
  result_count_full = 0
  book_jumps.clear
  if (show_all)
    book_jumps.set_show_all(true)
  end

  if book_filter != "all"
    book_jumps.set_book(book_filter)
  end
  book_jumps.set_term(term)

  db.query sql_count, "#{term.upcase}" do |resultset|
    resultset.each do
      result_count_book_name = resultset.read(String)
      result_count_book_num = resultset.read(Int32)

      # Log.info { "count query book: #{result_count_book_name} = #{result_count_book_num}"}

      chart.update_num(result_count_book_name, result_count_book_num, "Bible") 

      # Book jumps
      if !book_jumps.contains(result_count_book_name)
        book_jumps.add(result_count_book_name)
      end

      result_count_full += result_count_book_num
    end
  end
  # Log.info { "SQL count: #{sql_count}" }
  # Log.info { "Result Count: #{result_count_full}" }

  result_count = 0 # Reset
  bk = String.new
  chp = 0
  vs = 0
  vsnum = 0
  content = String.new
  prev_bk : String = ""
 
  # Search Hits
  db.query sql, "#{term.upcase}" do |resultset|
    resultset.each do
      result_count += 1

      bk = resultset.read(String)
      chp = resultset.read(Int32)
      vs = resultset.read(Int32)
      vsnum = resultset.read(Int32)
      content = resultset.read || ""

      heb = resultset.read || ""
      gk = resultset.read || ""

      sresults.add_id(vsnum) 

      content = highlight_english_word(term, content.to_s)

      # Book jumps - anchor
      if prev_bk != bk
        results_array << "<a name='#{bk}'></a>"
      end

      prev_bk = bk

      # Append the new results to the results array - full div contents
      # TODO: Make styling configurable (or from .env)
      results_array << "<div class='verse-eng' id='#{bk}-#{chp}-#{vs}'><a style='text-decoration: none;' href='/books/#{bk}.html##{chp}-#{vs}'>#{bk} #{chp}:#{vs}</a> <span class='verse-eng'>#{content}</span><span style='display: block; padding: 0 1em 0 2em;'>#{heb}#{gk}</span></div>"
      results = "changed to array"
    end

    # If this isn't already in the list of previous searches, add it
    # ...but only if all results are shown
    if result_count_full == result_count
      append_if_new(sresults, search_history)
    end

  end

  chart_book_array = chart.book_array_full

  # Add cookie, if there are results
  if result_count > 0
    search_history.add_and_render(env, term, "en")
    chart_hit_array = chart.empty_hit_array_full
    chart_percent_array = chart.empty_hit_array_full
  else
    chart_hit_array = chart.empty_hit_array_full
    chart_percent_array = chart.empty_hit_array_full
  end

  # Pull in the Strongs definition
  strongs_def = get_strongs_greek(db, term)

  env.response.status_code = 200
  env.response.content_type = "text/html; charset=utf-8"

  render "src/views/results.ecr"
end

# Placeholder - redirect to Greek search
get "/search/morph/:word" do |env|
  env.redirect "/search/gk/#{env.params.url["word"]}"
end

# Greek search
get "/search/gk/:word" do |env|
  results_array = [] of String

  chart = BcvChart.new("NT")
  trans = "gk"
  term = env.params.url["word"]
  show_all = env.params.query["show_all"]?
  set_chart_type(env, chart)
  pos = nil

  sresults = SearchResults.new(term, trans)

  # Log.info { "SHOW ALL: #{show_all}" }

  results = ""
  result_count = 0
  book_jumps.clear

  # Query: Counts
  sql_count = "SELECT count(*)
  from morph_verses as mv
        left join " + ENV["BASE_ENG_TRANS"] + "_verses as nv on
          nv.Book = mv.Book and
          nv.Chapter = mv.Chapter and
          nv.Verse = mv.Verse
        where mv.BCV in (select BookName || \"-\" || Chapter || \":\" || Verse from morph where Lemma = $1)"
  result_count_full = 0
  db.query sql_count, "#{term}" do |resultset|
    resultset.each do
      result_count_full = resultset.read(Int32)
    end
  end

  # Query: Hits
  sql = "SELECT nv.*, mv.ContentProcessed
  from morph_verses as mv
        left join " + ENV["BASE_ENG_TRANS"] + "_verses as nv on
          nv.Book = mv.Book and
          nv.Chapter = mv.Chapter and
          nv.Verse = mv.Verse
        where mv.BCV in (select BookName || \"-\" || Chapter || \":\" || Verse from morph where Lemma = $1) ORDER BY versenum  "
  if !show_all
    sql += " LIMIT #{DEFAULT_LIMIT}"
  end

  # Log.info { "SQL: #{sql}" }

  # Run the query and parse the results
  db.query sql, "#{term}" do |resultset|
    resultset.each do
      result_count += 1

      bk = resultset.read(String)
      chp = resultset.read || ""
      vs = resultset.read || ""
      vsnum = resultset.read(Int32)
      content = resultset.read || ""

      gk = resultset.read || ""

      chart.update(bk, "NT")

      sresults.add_id(vsnum)
      
      # Book jumps
      if !book_jumps.contains(bk)
        book_jumps.add(bk)
        results_array << "<a name='#{bk}'></a>"
      end

      # Find the root and replace the final word
      gk = highlight_greek_by_lemma(term, gk.to_s)

      results_array << "<div class='verse-eng' id='#{bk}-#{chp}-#{vs}'><a style='text-decoration: none;' href='/books/#{bk}.html##{chp}-#{vs}'>#{bk} #{chp}:#{vs}</a>\n<span class='verse-eng'>#{content}</span>\n<span style='display: block; padding: 0 1em 0 2em;'><!-- start gk -->#{gk}<!-- /gk --></span></div>"
    end

    if result_count_full == result_count
      append_if_new(sresults, search_history)
    end

  end

  chart_book_array = chart.book_array_nt
  chart_hit_array = chart.empty_hit_array_nt
  chart_percent_array = chart.empty_hit_array_nt

  # Add cookie, if there are results
  if result_count > 0
    search_history.add_and_render(env, term, "gk")
  end

  strongs_def = get_strongs_greek(db, term)

  # Render the page
  env.response.status_code = 200
  env.response.content_type = "text/html; charset=utf-8"

  render "src/views/results.ecr"
end

# Greek search with Parts of Speech (POS)
get "/search/gk/:word/:pos" do |env|
  results_array = [] of String

  chart = BcvChart.new("NT")
  trans = "gk"
  term = env.params.url["word"]
  pos = env.params.url["pos"]
  show_all = env.params.query["show_all"]?
  set_chart_type(env, chart)

  sresults = SearchResults.new(term, trans)

  # Log.info { "SHOW ALL: #{show_all}" }

  results = ""
  result_count = 0
  book_jumps.clear

  # Query: Counts
  sql_count = "SELECT count(*)
  from morph_verses as mv
        left join " + ENV["BASE_ENG_TRANS"] + "_verses as nv on
          nv.Book = mv.Book and
          nv.Chapter = mv.Chapter and
          nv.Verse = mv.Verse
        where mv.BCV in (select BookName || \"-\" || Chapter || \":\" || Verse from morph where Lemma = $1 AND Morph=$2)"
  result_count_full = 0
  db.query sql_count, "#{term}", "#{pos}" do |resultset|
    resultset.each do
      result_count_full = resultset.read(Int32)
    end
  end

  # Query: Hits
  sql = "SELECT nv.*, mv.ContentProcessed
  from morph_verses as mv
        left join " + ENV["BASE_ENG_TRANS"] + "_verses as nv on
          nv.Book = mv.Book and
          nv.Chapter = mv.Chapter and
          nv.Verse = mv.Verse
        where mv.BCV in (select BookName || \"-\" || Chapter || \":\" || Verse from morph where Lemma = $1 AND Morph=$2) ORDER BY versenum  "
  if !show_all
    sql += " LIMIT #{DEFAULT_LIMIT}"
  end

  # Log.info { "SQL: #{sql}; term: ${term}; pos: #{pos}" }

  # Run the query and parse the results
  db.query sql, "#{term}", "#{pos}" do |resultset|
    resultset.each do
      result_count += 1

      bk = resultset.read(String)
      chp = resultset.read || ""
      vs = resultset.read || ""
      vsnum = resultset.read(Int32)
      content = resultset.read || ""

      gk = resultset.read || ""

      chart.update(bk, "NT")

      sresults.add_id(vsnum)

      # Book jumps
      if !book_jumps.contains(bk)
        book_jumps.add(bk)
        results_array << "<a name='#{bk}'></a>"
      end

      # Find the root and replace the final word
      gk = highlight_greek_by_lemma(term, gk.to_s)

      results_array << "<div class='verse-eng' id='#{bk}-#{chp}-#{vs}'><a style='text-decoration: none;' href='/books/#{bk}.html##{chp}-#{vs}'>#{bk} #{chp}:#{vs}</a> <span class='verse-eng'>#{content}</span><span style='display: block; padding: 0 1em 0 2em;'>#{gk}</span></div>"
    end

    if result_count_full == result_count
      append_if_new(sresults, search_history)
    end

  end

  chart_book_array = chart.book_array_nt
  chart_hit_array = chart.empty_hit_array_nt
  chart_percent_array = chart.empty_hit_array_nt

  # Add cookie, if there are results
  if result_count > 0
    search_history.add_and_render(env, term, "gk")
  end

  strongs_def = get_strongs_greek(db, term)

  # Render the page
  env.response.status_code = 200
  env.response.content_type = "text/html; charset=utf-8"

  render "src/views/results.ecr"
end

# Hebrew search
get "/search/heb/:word" do |env|
  results_array = [] of String

  chart = BcvChart.new("OT")
  term = env.params.url["word"]
  show_all = env.params.query["show_all"]?
  set_chart_type(env, chart)
  pos = nil

  trans = "heb"
  results = ""
  result_count = 0
  book_jumps.clear
  
  sresults = SearchResults.new(term, trans)

  result_count_full = 0
  sql_count = "select count(*) from
        heb_verses as hv
    left join books as bks on
        hv.book = bks.name
    left join " + ENV["BASE_ENG_TRANS"] + "_verses as nv on
        nv.Book = bks.abbrev and
        nv.Chapter = hv.Chapter and
        nv.Verse = hv.Verse
    where  hv.book || \"-\" || hv.Chapter || \":\" || hv.verse in (select book || \"-\" || Chapter || \":\" || Verse
    from heb
    left join books on
        books.name = heb.book
    where strong = ?) LIMIT 1"

  db.query sql_count, "#{term}" do |resultset|
    resultset.each do
      result_count_full = resultset.read(Int32)
    end
  end

  sql = "select nv.*, hv.ContentProcessed as hebContent, null as ContentProcessed from
        heb_verses as hv
    left join books as bks on
        hv.book = bks.name
    left join " + ENV["BASE_ENG_TRANS"] + "_verses as nv on
        nv.Book = bks.abbrev and
        nv.Chapter = hv.Chapter and
        nv.Verse = hv.Verse
    where  hv.book || \"-\" || hv.Chapter || \":\" || hv.verse in (select book || \"-\" || Chapter || \":\" || Verse
    from heb
    left join books on
        books.name = heb.book
    where strong = ?)"

  # STDERR.puts "SQL: #{sql}"

  if !show_all
    sql = "#{sql} LIMIT #{DEFAULT_LIMIT}"
  end

  db.query sql, "#{term}" do |resultset|
    resultset.each do
      result_count += 1

      bk = resultset.read || ""
      chp = resultset.read || ""
      vs = resultset.read || ""
      vsnum = resultset.read(Int32)
      content = resultset.read || ""

      heb = resultset.read || ""
      gk = resultset.read || ""

      sresults.add_id(vsnum)

      bkname = String.new
      if bk == 0
        STDERR.puts "bk is empty @ 309"
        bkname = "UNDEF"
      else
        # STDERR.puts "bk: #{bk}"
        bkname = bk.to_s
      end

      if bkname != "UNDEF"
        # STDERR.puts "updating chart for #{bkname}"
        chart_update_result = chart.update(bkname, "OT")
        if chart_update_result["code"] != "OK"
          STDERR.puts "chart update error: #{chart_update_result["message"]}"
        end

        # Book jumps
        if !book_jumps.contains(bkname)
          book_jumps.add(bkname)
          results_array << "<a name='#{bkname}'></a>"
        end
      end

      results_array << "<div class='verse-eng' id='#{bk}-#{chp}-#{vs}'><a style='text-decoration: none;' href='/books/#{bk}.html##{chp}-#{vs}'>#{bk} #{chp}:#{vs}</a> <span class='verse-eng'>#{content}</span><span style='display: block; padding: 0 1em 0 2em;'>#{heb}#{gk}</span></div>"
    end

    if result_count_full == result_count
      append_if_new(sresults, search_history)
    end

    # Prepend Strong's defn
    # results = "<div class=\"row g-1\" style=\"display: block; border: blue; border-style: double; padding: 5px; margin: 5px;\" id=\"strongs-results\">#{get_strongs_hebrew(db, term)}</div>#{results}"
  end

  chart_book_array = chart.book_array_ot
  chart_hit_array = chart.empty_hit_array_ot
  chart_percent_array = chart.empty_hit_array_ot

  # Add cookie, if there are results
  if result_count > 0
    search_history.add_and_render(env, term, "heb")
  end

  strongs_def = get_strongs_hebrew(db, term)

  # Render the page
  env.response.status_code = 200
  env.response.content_type = "text/html; charset=utf-8"
  render "src/views/results.ecr"
end

# Strongs English search
get "/strongs/:word" do |env|
  term = env.params.url["word"]
  results = result_count = String.new

  # Render the page
  env.response.status_code = 200
  env.response.content_type = "text/html; charset=utf-8"
  render "src/views/strongs.ecr"
end

# Strong's Hebrew popup
get "/strongs-heb/:word" do |env|
  term = env.params.url["word"]
  strong_id : String = ""
  lemma : String = ""
  xlit : String = ""
  pronounce : String = ""
  description : String = ""

  sql = "select *
        from strongs2
        where
        number
        in (select distinct 'H' || strong_id
            from heb
            where strong=?
        )"
  # results = String.new
  result_count = 0

  db.query sql, "#{term}" do |resultset|
    resultset.each do
      result_count += 1

      strong_id = resultset.read(String)
      lemma = resultset.read(String)
      xlit = resultset.read(String)
      pronounce = resultset.read(String)
      description = resultset.read(String)
    end
  end

  # Render the page
  render "src/views/strongs_heb.ecr"
end

# Strong's Greek popup
get "/strongs/:word/:pos" do |env|
  term = env.params.url["word"]
  pos = env.params.url["pos"]
  # results = ""
  result_count = 0

  # Count the occurrences
  sql = "SELECT count(*) as ctr
  from morph_verses as mv
        left join " + ENV["BASE_ENG_TRANS"] + "_verses as nv on
          nv.Book = mv.Book and
          nv.Chapter = mv.Chapter and
          nv.Verse = mv.Verse
        where mv.BCV in (select BookName || \"-\" || Chapter || \":\" || Verse from morph where Lemma = $1)"
  db.query sql, "#{term}" do |resultset|
    resultset.each do
      result_count = resultset.read(Int32)
    end
  end

  # Get the Strong's definition and data
  sql = "SELECT word, strongs_def, kjv_def, lemma, translit, derivation FROM strongs WHERE word=?"

  # STDERR.puts "SQL: #{sql} #{term}"

  word = ""
  strongs_def = ""
  kjv_def = ""
  lemma = ""
  xlit = ""
  derivation = ""

  db.query sql, "#{term}" do |resultset|
    resultset.each do
      word = resultset.read(String)
      strongs_def = resultset.read(String)
      kjv_def = resultset.read(String)
      lemma = resultset.read(String)
      xlit = resultset.read(String)
      derivation = resultset.read(String)
    end
  end

  # Render the page
  env.response.status_code = 200
  env.response.content_type = "text/html; charset=utf-8"

  render "src/views/strongs_gk.ecr"
end

# Show the Union/Difference/Intersection options
get "/pick/:id" do |env|
  id = env.params.url["id"]

  render "src/views/combo.ecr"
end

# Union
get "/and/:id1/:id2" do |env|
  combo_type : String = "AND"

  id1 = env.params.url["id1"].to_i
  id2 = env.params.url["id2"].to_i
  
  list1 : Array(Int32) = search_history.@search_results[id1].@verse_ids
  list2 = search_history.@search_results[id2].@verse_ids

  combined = list1.concat(list2).sort.uniq!

  sql = "SELECT nv.*,heb_verses.ContentProcessed as hebContent,  mv.ContentProcessed from " + ENV["BASE_ENG_TRANS"] + "_verses as nv
  left join morph_verses as mv on
    nv.Book = mv.Book and
    nv.Chapter = mv.Chapter and
    nv.Verse = mv.Verse
  left join books as bks on
    nv.Book = bks.abbrev
  left join heb_verses on
    bks.name = heb_verses.book AND
    nv.Chapter = heb_verses.chapter AND
    nv.Verse = heb_verses.verse
  where nv.VerseNum in (" + combined.join(", ") + ") ORDER BY nv.versenum"

  chart = BcvChart.new("Bible")
  
  results = ""
  result_count = 0

  set_chart_type(env, chart)

  book_jumps.clear

  db.query sql do |resultset|
    resultset.each do
      result_count += 1

      bk = resultset.read(String)
      chp = resultset.read(Int32)
      vs = resultset.read(Int32)
      vsnum = resultset.read(Int32)
      content = resultset.read(String)

      heb = resultset.read || ""
      gk = resultset.read || ""

      chart.update(bk, "Bible") 

      # Book jumps
      if !book_jumps.contains(bk)
        book_jumps.add(bk)
        results += "<a name='#{bk}'></a>"
      end

      content = highlight_english_word(search_history.@search_results[id1].@word, content.to_s)
      content = highlight_english_word(search_history.@search_results[id2].@word, content)
      gk = highlight_greek_by_lemma(search_history.@search_results[id1].@word, gk.to_s)
      gk = highlight_greek_by_lemma(search_history.@search_results[id2].@word, gk)
      
      results = "#{results}<div class='verse-eng' id='#{bk}-#{chp}-#{vs}'><a style='text-decoration: none;' href='/books/#{bk}.html##{chp}-#{vs}'>#{bk} #{chp}:#{vs}</a> <span class='verse-eng'>#{content}</span><span style='display: block; padding: 0 1em 0 2em;'>#{heb}#{gk}</span></div>"
    end

    set_chart_type(env, chart)
    chart_book_array = chart.book_array_full

    search_history.render(env)

    render "src/views/combo2.ecr"
  end
end

# Difference - A excluding overlapping B
get "/not/:id1/:id2" do |env|
  combo_type : String = "NOT"
  id1 = env.params.url["id1"].to_i
  id2 = env.params.url["id2"].to_i

  list1 : Array(Int32) = search_history.@search_results[id1].@verse_ids
  list2 = search_history.@search_results[id2].@verse_ids

  combined = list1.select { |number| 
      !list2.includes?(number)
  }

  sql = "SELECT nv.*,heb_verses.ContentProcessed as hebContent,  mv.ContentProcessed from " + ENV["BASE_ENG_TRANS"] + "_verses as nv
  left join morph_verses as mv on
    nv.Book = mv.Book and
    nv.Chapter = mv.Chapter and
    nv.Verse = mv.Verse
  left join books as bks on
    nv.Book = bks.abbrev
  left join heb_verses on
    bks.name = heb_verses.book AND
    nv.Chapter = heb_verses.chapter AND
    nv.Verse = heb_verses.verse
  where nv.VerseNum in (" + combined.join(", ") + ") ORDER BY nv.versenum"

  chart = BcvChart.new("Bible")

  results = ""
  result_count = 0

  set_chart_type(env, chart)
  chart_book_array = chart.book_array_full

  book_jumps.clear

  db.query sql do |resultset|
    resultset.each do
      result_count += 1

      bk = resultset.read(String)
      chp = resultset.read(Int32)
      vs = resultset.read(Int32)
      vsnum = resultset.read(Int32)
      content = resultset.read(String)

      heb = resultset.read || ""
      gk = resultset.read || ""

      chart.update(bk, "Bible") 

      # Book jumps
      if !book_jumps.contains(bk)
        book_jumps.add(bk)
        results += "<a name='#{bk}'></a>"
      end

      content = highlight_english_word(search_history.@search_results[id1].@word, content.to_s)
      content = highlight_english_word(search_history.@search_results[id2].@word, content)
      gk = highlight_greek_by_lemma(search_history.@search_results[id1].@word, gk.to_s)
      gk = highlight_greek_by_lemma(search_history.@search_results[id2].@word, gk)
      
      results = "#{results}<div class='verse-eng' id='#{bk}-#{chp}-#{vs}'><a style='text-decoration: none;' href='/books/#{bk}.html##{chp}-#{vs}'>#{bk} #{chp}:#{vs}</a> <span class='verse-eng'>#{content}</span><span style='display: block; padding: 0 1em 0 2em;'>#{heb}#{gk}</span></div>"
    end

    set_chart_type(env, chart)
    chart_book_array = chart.book_array_full
  end

  search_history.render(env)

  render "src/views/combo2.ecr"
end

# Intersection - A overlaps B
get "/intersect/:id1/:id2" do |env|
  combo_type : String = "INTERSECT"
  id1 = env.params.url["id1"].to_i
  id2 = env.params.url["id2"].to_i

  list1 : Array(Int32) = search_history.@search_results[id1].@verse_ids
  list2 = search_history.@search_results[id2].@verse_ids

  # combined = list1 & list2
  combined = list1.select { |number| 
    list2.includes?(number)
  }
  combined.sort

  sql = "SELECT nv.*,heb_verses.ContentProcessed as hebContent,  mv.ContentProcessed from " + ENV["BASE_ENG_TRANS"] + "_verses as nv
  left join morph_verses as mv on
    nv.Book = mv.Book and
    nv.Chapter = mv.Chapter and
    nv.Verse = mv.Verse
  left join books as bks on
    nv.Book = bks.abbrev
  left join heb_verses on
    bks.name = heb_verses.book AND
    nv.Chapter = heb_verses.chapter AND
    nv.Verse = heb_verses.verse
  where nv.VerseNum in (" + combined.join(", ") + ") ORDER BY nv.versenum"

  chart = BcvChart.new("Bible")

  results = ""
  result_count = 0

  set_chart_type(env, chart)
  chart_book_array = chart.book_array_full

  book_jumps.clear

  db.query sql do |resultset|
    resultset.each do
      result_count += 1

      bk = resultset.read(String)
      chp = resultset.read(Int32)
      vs = resultset.read(Int32)
      vsnum = resultset.read(Int32)
      content = resultset.read(String)

      heb = resultset.read || ""
      gk = resultset.read || ""

      chart.update(bk, "Bible") 

      # Book jumps
      if !book_jumps.contains(bk)
        book_jumps.add(bk)
        results += "<a name='#{bk}'></a>"
      end

      content = highlight_english_word(search_history.@search_results[id1].@word, content.to_s)
      content = highlight_english_word(search_history.@search_results[id2].@word, content)
      gk = highlight_greek_by_lemma(search_history.@search_results[id1].@word, gk.to_s)
      gk = highlight_greek_by_lemma(search_history.@search_results[id2].@word, gk)

      results = "#{results}<div class='verse-eng' id='#{bk}-#{chp}-#{vs}'><a style='text-decoration: none;' href='/books/#{bk}.html##{chp}-#{vs}'>#{bk} #{chp}:#{vs}</a> <span class='verse-eng'>#{content}</span><span style='display: block; padding: 0 1em 0 2em;'>#{heb}#{gk}</span></div>"
    end

    set_chart_type(env, chart)
    chart_book_array = chart.book_array_full
  end

  search_history.render(env)

  render "src/views/combo2.ecr"
end

Kemal.run

db.close
