require "./spec_helper"

describe BcvChart do
  it "NT size is 27" do
    bc = BcvChart.new("NT")
    bc.hits().size.should eq(27)
  end

  it "OT size is 39" do
    bcot = BcvChart.new("OT")
    bcot.hits().size.should eq(39)
  end

  it "Update valid book" do
    bc = BcvChart.new("NT")
    bc.update("Mat", "NT").should eq({"code" => "OK", "message" => "Success: Mat, NT updated to 1"})
    bc.update("Mat", "NT").should eq({"code" => "OK", "message" => "Success: Mat, NT updated to 2"})
  end

  it "Update invalid book" do
    bc = BcvChart.new("NT")
    bc.update("Xyz", "NT").should eq({"code" => "ERR", "message" => "Error 45: Xyz not found in @@bible_array"})
  end
end
