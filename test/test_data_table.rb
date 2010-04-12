require 'helper'

class TestDataTable < Test::Unit::TestCase
  context "A DataTable instance" do
    setup do
      
      class OrderPosition
        attr_accessor :articlenum
        attr_accessor :name
        attr_accessor :ordered
        attr_accessor :group
        attr_accessor :quantity
        attr_accessor :price
      
        def initialize(articlenum, name, group, ordered, quantity, price)
          @articlenum = articlenum
          @name = name
          @group = group
          @ordered = ordered
          @quantity = quantity
          @price = price
        end
      end
      
      @order_positions = [ 
        OrderPosition.new("AB36KAAA", "Laser Sword", "AA", Date.new(2009, 10, 4), 1, 1000.0),
        OrderPosition.new("D81ADG7A", "R2DX",        "AA", Date.new(2009, 9, 4),  1, 100.0 ),
        OrderPosition.new("D81ADG7A", "R2DX",        "AA", Date.new(2009, 9, 4),  1, 10.0 ),
        OrderPosition.new("DTJA6181", "R2DX",        "BB", Date.new(2009, 10, 4), 1, 200.0 ),
        OrderPosition.new("DTJA6181", "R2DX",        "BB", Date.new(2009, 10, 4), 1, 20.0 )
      ]
    end
    
    should "work properly" do
      
      t = DataTable.new
      
      # variant 1: implicit method lookup
      t.add_column(:articlenum, "Articlenum")
      t.add_column(:name, "Product Name")
      t.add_column(:ordered, "Datum")
      t.add_column(:group, "Product Group")
      # variant 2: explicit transformer function that yields an item of your collection 
      t.add_column(:amount, "Amount", lambda { |p| p.quantity*p.price })
      # variant 3: explicit row modification (see build_rows!)
      t.add_column(:doubled_price, "Doubled Price")
      
      t.build_rows(@order_positions) do |row, p| # block can be omitted
        row[:doubled_price] = p.price*2
      end
      
      grouped_table = t.group_by(:ordered, {
        :amount => DataTable::Aggregators::SUM,
        :doubled_price => DataTable::Aggregators::SUM
      }, lambda {|x| x.year.to_s+"-"+x.month.to_s})
      
      # puts t.render_csv(:col_sep => ",")
      puts grouped_table.render_csv(:col_sep => ",")
    end
    
    
    
  end
end
