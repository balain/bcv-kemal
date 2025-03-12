# Default limit for number of results to return from database queries
DEFAULT_LIMIT = 500

# Returns a hash containing Strong's Hebrew lexicon data for the given word number
#
# Parameters:
#   db : DB::Database - SQLite database connection
#   word : String - Strong's Hebrew number (e.g. "H1234")
#
# Returns a hash with the following keys:
#   strongs_word : String - The input Strong's number
#   strongs_def : String - The Strong's definition
#   kjv_def : String - The KJV definition (same as strongs_def for Hebrew)
#   lemma : String - The Hebrew lemma
#   translit : String - Transliteration of the Hebrew word
#   derivation : String - Word derivation (empty for Hebrew)
def get_strongs_hebrew(db, word)
  # strong_results = ""
  strong_results_count = 0
  sql = "select *
        from strongs2
        where
        number
        in (select distinct 'H' || strong_id
            from heb
            where strong=?
        )"
  lemma = ""
  xlit = ""
  description = ""

  db.query sql, "#{word}" do |resultset|
    resultset.each do
      strong_results_count += 1
      # strong_id = resultset.read(String)
      _ = resultset.read(String)
      lemma = resultset.read(String)
      xlit = resultset.read(String)
      # pronounce = resultset.read(String)
      _ = resultset.read(String)
      description = resultset.read(String)

      # strong_results = "#{strong_results}#{strong_id}: #{lemma} (xlit: #{xlit}; /#{pronounce}/; #{description})"
    end
  end

  {"strongs_word" => word,
   "strongs_def"  => description,
   "kjv_def"      => description,
   "lemma"        => lemma,
   "translit"     => xlit,
   "derivation"   => ""}
end

def get_strongs_greek(db, word)
  # Get the Strong's definition and data
  sql = "SELECT word, strongs_def, kjv_def, lemma, translit, derivation FROM strongs WHERE word=?"

  strongs_word = ""
  strongs_def = ""
  kjv_def = ""
  lemma = ""
  xlit = ""
  derivation = ""

  db.query sql, "#{word}" do |resultset|
    resultset.each do
      strongs_word = resultset.read(String)
      strongs_def = resultset.read(String)
      kjv_def = resultset.read(String)
      lemma = resultset.read(String)
      xlit = resultset.read(String)
      derivation = resultset.read(String)
    end
  end

  {"strongs_word" => strongs_word, "strongs_def" => strongs_def, "kjv_def" => kjv_def, "lemma" => lemma, "translit" => xlit, "derivation" => derivation}
end
