require 'helper'

class TestDataTable < Test::Unit::TestCase
  context "A DataTable instance" do
    setup do
      
      class OrderPosition
        attr_accessor :articlenum
        attr_accessor :name
        attr_accessor :quantity
        attr_accessor :price
      
        def initialize(articlenum, name, quantity, price)
          @articlenum = articlenum
          @name = name
          @quantity = quantity
          @price = price
        end
      end
    
      @order_positions = [ OrderPosition.new("AB36KAA", "Laser Sword", 4, 1231.45), OrderPosition.new("D81ADG7A", "R2DX", 2, 42001.04 ) ]
    end
  
    should "work properly" do
      t = DataTable.new
      # variant 1: implicit method lookup
      t.add_column(:articlenum, "Articlenum")
      t.add_column(:name, "Product Name")
      # variant 2: explicit transformer function that yields an item of your collection 
      t.add_column(:amount, "Amount", lambda { |p| p.quantity*p.price })
      # variant 3: explicit row modification see build_rows! 
      t.add_column(:doubled_price, "Doubled Price")
      
      t.build_rows!(@order_positions) do |row, p| # block can be omitted
        row[:doubled_price] = p.price*2
      end
      puts t.render_csv(:col_sep => ";")
    end
  end
end
