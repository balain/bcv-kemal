class SearchResults
    @word : String
    @trans : String
    @query : String
    
    def initialize(term, trans)
        @word = term
        @trans = trans
        @query = ""
        @verse_ids = [] of Int32
    end

    def set_query(query)
        @query = query
    end

    def add_id(id)
        @verse_ids << id
    end

    def set_ids(verse_ids)
        @verse_ids = verse_ids
    end

    def get_word()
        @word
    end

end