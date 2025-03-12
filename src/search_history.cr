require "./search_results"

class SearchHistory
  def initialize
    @word_history = [] of String
    @trans_history = [] of String
    @search_results = [] of SearchResults
  end

  def add(word : String, trans : String = "en")
    if !@word_history.includes?(word)
      @word_history << word
      @trans_history << trans
    end
  end

  def fetch
    {@word_history, @trans_history}
  end

  def add_and_render(env, word : String, trans : String = "en")
    add(word, trans)
    render(env)
  end

  def render(env)
    # Encode history to handle Greek and Hebrew words
    env.response.cookies << HTTP::Cookie.new(name: "word_history", value: URI.encode_path(@word_history.join("|")), path: "/", expires: Time.local + Time::Span.new(hours: 24))
    env.response.cookies << HTTP::Cookie.new(name: "trans_history", value: @trans_history.join("|"), path: "/", expires: Time.local + Time::Span.new(hours: 24))
  end

  def links
    links = [] of String
    @word_history.each_with_index do |word, i|
      if @trans_history[i] == "gk"
        links.unshift("<span id='gk-tippy' word='#{word}' syn='undef'>#{word}</span>")
      elsif @trans_history[i] == "heb"
        links.unshift("<span id='heb-tippy' word='#{word}' syn='undef'>#{word}</span>")
      else
        links.unshift("<a href=\"/search/#{@trans_history[i]}/#{word}\" class=\"previous\">#{word}</a>")
      end
    end
    "<div class='previous'>#{links.join(" | ")}</div>"
  end
end
