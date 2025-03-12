class BookJumps

  def initialize
    @book_jumps = Hash(String, Bool).new
    @book_filter = "UNDEF"
    @term = "UNDEF"
    @show_all = false
  end

  def set_book(book)
    @book_filter = book
  end

  def set_last_book(book)
    @last_book = book
  end

  def set_show_all(show_all)
    @show_all = show_all
  end

  def set_term(term)
    @term = term
  end

  def clear
    @book_jumps = Hash(String, Bool).new
  end

  def add(book)
    @book_jumps[book] = true
  end

  def contains(book)
    @book_jumps.has_key?(book)
  end

  def remove(book)
    @book_jumps.delete(book)
  end

  def as_html
    # Log.info { "jumps.as_html called: @book_filter: #{@book_filter}" }
    html = "<div id='book-jumps'>"
    @book_jumps.each do |book, _|
      # Log.info { "... book: #{book}" }
      # Show local link if show_all or book_filter = book
      if @book_filter == book || @show_all
        html += "<a href='##{book}'>#{book}</a> "
      else
        # Link to other search
        # TODO fix this book link - show when necessary
        html += "<a href='/search/en/#{@term}/#{book}'>#{book}</a> "
      end
    end
    html += "</div>"
  end
end
