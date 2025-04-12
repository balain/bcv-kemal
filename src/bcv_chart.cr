enum ChartType
  Dimple
  Plotly
end

class BcvChart
  @@bible_array = ["Gen", "Exo", "Lev", "Num", "Deu", "Jos", "Jdg", "Rut", "1Sa", "2Sa", "1Ki", "2Ki", "1Ch", "2Ch", "Ezr", "Neh", "Est", "Job", "Psa", "Pro", "Ecc", "Sol", "Isa", "Jer", "Lam", "Eze", "Dan", "Hos", "Joe", "Amo", "Oba", "Jon", "Mic", "Nah", "Hab", "Zep", "Hag", "Zec", "Mal", "Mat", "Mar", "Luk", "Joh", "Act", "Rom", "1Co", "2Co", "Gal", "Eph", "Phi", "Col", "1Th", "2Th", "1Ti", "2Ti", "Tit", "Phm", "Heb", "Jam", "1Pe", "2Pe", "1Jo", "2Jo", "3Jo", "Jud", "Rev"]
  @@ot_array = ["Gen", "Exo", "Lev", "Num", "Deu", "Jos", "Jdg", "Rut", "1Sa", "2Sa", "1Ki", "2Ki", "1Ch", "2Ch", "Ezr", "Neh", "Est", "Job", "Psa", "Pro", "Ecc", "Sol", "Isa", "Jer", "Lam", "Eze", "Dan", "Hos", "Joe", "Amo", "Oba", "Jon", "Mic", "Nah", "Hab", "Zep", "Hag", "Zec", "Mal"]
  @@nt_array = ["Mat", "Mar", "Luk", "Joh", "Act", "Rom", "1Co", "2Co", "Gal", "Eph", "Phi", "Col", "1Th", "2Th", "1Ti", "2Ti", "Tit", "Phm", "Heb", "Jam", "1Pe", "2Pe", "1Jo", "2Jo", "3Jo", "Jud", "Rev"]
  @@word_count_array = [37448, 31916, 24265, 31689, 27664, 18662, 18447, 2517, 24452, 20162, 23755, 22817, 19777, 24882, 6922, 9978, 5465, 17322, 43203, 14857, 5458, 2717, 36149, 42203, 3365, 37781, 11764, 5084, 1942, 4115, 628, 1282, 3031, 1186, 1412, 1573, 1082, 6262, 1802, 23556, 14849, 25803, 19522, 24514, 9730, 9659, 6237, 3223, 3174, 2281, 2132, 1923, 1107, 2460, 1669, 913, 473, 7078, 2412, 2544, 1565, 2553, 316, 319, 642, 12005]
  @scope : String
  @type = ChartType::Dimple

  def initialize(scope : String)
    @scope = scope
    ctr = @@bible_array.size

    if @scope == "OT"
      ctr = @@ot_array.size
    elsif @scope == "NT"
      ctr = @@nt_array.size
    end

    @hit_array = [] of Int32
    @percent_array = [] of Float64

    # STDERR.puts "chart scope = #{scope}; ctr = #{ctr}"

    i = 1
    while i <= ctr
      @hit_array << 0
      @percent_array << 0
      i += 1
    end
    # STDERR.puts @hit_array
  end

  def set_chart_type(type : ChartType)
    @type = type
  end

  def update(book_name : String, scope : String)
    update_num(book_name, 1, scope)
  end

  def update_num(book_name : String, hits : Int32, scope : String)
    # STDERR.puts "update(#{book_name} called...)"

    result = {"code" => "OK", "message" => "TBD"}

    case scope
    when "OT"
      bk_ndx = @@ot_array.index(book_name) || -1
    when "NT"
      bk_ndx = @@nt_array.index(book_name) || -1
    else
      bk_ndx = @@bible_array.index(book_name) || -1
    end
    # Convert book name to index

    if bk_ndx == -1
      result["code"] = "ERR"
      result["message"] = "Error 45: #{book_name} not found in @@bible_array"
    elsif bk_ndx
      @hit_array[bk_ndx] += hits
      result["code"] = "OK"
      result["message"] = "Success: #{book_name}, #{scope} updated to #{@hit_array[bk_ndx]}"
    else
      result["code"] = "ERR"
      result["message"] = "Error 49: #{book_name} not found in @@bible_array"
    end

    result
  end

  def book_array_full
    "\"" + @@bible_array.join("\",\"") + "\""
  end

  def empty_hit_array_full
    @hit_array
  end

  def book_array_ot
    "\"" + ["Gen", "Exo", "Lev", "Num", "Deu", "Jos", "Jdg", "Rut", "1Sa", "2Sa", "1Ki", "2Ki", "1Ch", "2Ch", "Ezr", "Neh", "Est", "Job", "Psa", "Pro", "Ecc", "Sol", "Isa", "Jer", "Lam", "Eze", "Dan", "Hos", "Joe", "Amo", "Oba", "Jon", "Mic", "Nah", "Hab", "Zep", "Hag", "Zec", "Mal"].join("\",\"") + "\""
  end

  def empty_hit_array_ot
    @hit_array
  end

  def book_array_nt
    "\"" + ["Mat", "Mar", "Luk", "Joh", "Act", "Rom", "1Co", "2Co", "Gal", "Eph", "Phi", "Col", "1Th", "2Th", "1Ti", "2Ti", "Tit", "Phm", "Heb", "Jam", "1Pe", "2Pe", "1Jo", "2Jo", "3Jo", "Jud", "Rev"].join("\",\"") + "\""
  end

  def empty_hit_array_nt
    @hit_array
  end

  def hits
    # STDERR.puts @hit_array
    @hit_array
  end

  def percents
    # Calculate percents before returning the array
    # STDERR.puts "size of hit_array: #{@hit_array.size}"
    # STDERR.puts "size of percent_array: #{@percent_array.size}"
    # STDERR.puts "size of word_count_array: #{@@word_count_array.size}"
    i = 0

    if @scope == "OT"
      arr_size = @@ot_array.size
    elsif @scope == "NT"
      arr_size = @@nt_array.size
    else
      arr_size = @@bible_array.size
    end
    while i < arr_size
      # STDERR.puts "i: #{i}; hit_array[#{i}]: #{@hit_array[i]}"
      # STDERR.puts "word_count_array[#{i}]: #{@@word_count_array[i]}"
      @percent_array[i] = 100 * (@hit_array[i] / @@word_count_array[i])
      i += 1
    end
    @percent_array
  end

  def dimple_data
    # Sample:
    #     { "Book":"Mat", "Hits": 2, "Perc":.053 },
    #     { "Book":"Mar", "Hits": 2, "Perc":.053 },
    #     ...
    data = String.new
    i : Int8 = 0
    if @scope == "OT"
      while i < @hit_array.size
        data += "{ 'Book':'#{@@ot_array[i]}', 'Hits': #{@hit_array[i]}, 'Perc':#{cal_percent(i)} },"
        i += 1
      end
    elsif @scope == "NT"
      while i < @hit_array.size
        data += "{ 'Book':'#{@@nt_array[i]}', 'Hits': #{@hit_array[i]}, 'Perc':#{cal_percent(i)} },"
        i += 1
      end
    else      
      while i < @hit_array.size
        data += "{ 'Book':'#{@@bible_array[i]}', 'Hits': #{@hit_array[i]}, 'Perc':#{cal_percent(i)} },"
        i += 1
      end
    end
    data
  end

  def cal_percent(ndx : Int8)
    100 * (@hit_array[ndx] / @@word_count_array[ndx])
  end


  def order_rule
    if @scope == "OT"
      "[\"" + ["Gen", "Exo", "Lev", "Num", "Deu", "Jos", "Jdg", "Rut", "1Sa", "2Sa", "1Ki", "2Ki", "1Ch", "2Ch", "Ezr", "Neh", "Est", "Job", "Psa", "Pro", "Ecc", "Sol", "Isa", "Jer", "Lam", "Eze", "Dan", "Hos", "Joe", "Amo", "Oba", "Jon", "Mic", "Nah", "Hab", "Zep", "Hag", "Zec", "Mal"].join("\",\"") + "\"]"
    elsif @scope == "NT"
      "[\"" + ["Mat", "Mar", "Luk", "Joh", "Act", "Rom", "1Co", "2Co", "Gal", "Eph", "Phi", "Col", "1Th", "2Th", "1Ti", "2Ti", "Tit", "Phm", "Heb", "Jam", "1Pe", "2Pe", "1Jo", "2Jo", "3Jo", "Jud", "Rev"].join("\",\"") + "\"]"
    else
      "[\"" + ["Gen", "Exo", "Lev", "Num", "Deu", "Jos", "Jdg", "Rut", "1Sa", "2Sa", "1Ki", "2Ki", "1Ch", "2Ch", "Ezr", "Neh", "Est", "Job", "Psa", "Pro", "Ecc", "Sol", "Isa", "Jer", "Lam", "Eze", "Dan", "Hos", "Joe", "Amo", "Oba", "Jon", "Mic", "Nah", "Hab", "Zep", "Hag", "Zec", "Mal", "Mat", "Mar", "Luk", "Joh", "Act", "Rom", "1Co", "2Co", "Gal", "Eph", "Phi", "Col", "1Th", "2Th", "1Ti", "2Ti", "Tit", "Phm", "Heb", "Jam", "1Pe", "2Pe", "1Jo", "2Jo", "3Jo", "Jud", "Rev"].join("\",\"") + "\"]"
    end
  end

  def scope
    @scope
  end

  def js_script_tag
    if @type == ChartType::Dimple
      "<script src=\"http://d3js.org/d3.v4.min.js\"></script><script src=\"http://dimplejs.org/dist/dimple.v2.3.0.min.js\"></script>"
    elsif @type == ChartType::Plotly
      "<script src=\"https://cdn.plot.ly/plotly-3.0.1.min.js\" charset=\"utf-8\"></script>"
    else
      "<!-- Unknown chart type: #{@type} -->"
    end
  end

  def html_script_div
    if @type == ChartType::Dimple
      "<div id=\"dimple-chart\"></div>"
    elsif @type == ChartType::Plotly
      "<div id=\"plotlyChart\"></div>"
    else
      "<!-- Unknown chart type: #{@type} -->"
    end
  end

  def js_script_content
    if @type == ChartType::Dimple
      "var svg = dimple.newSvg(\"#dimple-chart\", \"100%\", 150);
        var data = [
            #{dimple_data}
        ];
        var chart = new dimple.chart(svg, data);
        var x = chart.addCategoryAxis(\"x\", \"Book\");
        x.addOrderRule(#{order_rule});
        var y = chart.addMeasureAxis(\"y\", \"Hits\");
        var y2 = chart.addMeasureAxis(\"y\", \"Perc\");
        var s = chart.addSeries(\"Book\", dimple.plot.bar);
        chart.addSeries(\"Perc\", dimple.plot.line, [x, y2]);
        chart.setBounds(25, \"25px\", \"90%\", \"65%\");
        chart.draw();"
    elsif @type == ChartType::Plotly
      # Calc the book array
      if @scope == "OT"
        book_array = book_array_ot
      elsif @scope == "NT"
        book_array = book_array_nt
      else
        book_array = book_array_full
      end
      "var ctr = {
          x: [#{book_array}],
          y: #{hits},
          name: '#',
          type: 'bar'
        };
        
        var perc = {
          x: [#{book_array}],
          y: #{percents},
          name: 'perc',
          type: 'line',   yaxis: 'y2',
        };
        
        var data = [ctr, perc];
        
        var layout = { 
          autosize: true,
          margin: {
             autoexpand: true, b: 40, t:5, l:25, r:0, pad: 0, },
          height: 150,
          showlegend: false,
          yaxis: {
          },
          yaxis2: {
            minallowed: 0,
            overlaying: 'y',
            side: 'right', minimum: 0, 
          }
        };
        
        Plotly.newPlot('plotlyChart', data, layout, { responsive: true, displaylogo: false });"
    else
      "<!-- Unknown chart type: #{@type} -->"
    end
  end
end
