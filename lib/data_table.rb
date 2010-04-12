require 'fastercsv'

class DataTable
  class ColumnAlreadyExists < StandardError ; end
  class ColumnNotFound < StandardError ; end
  
  INFINITY = 1.0/0
  
  class Aggregators
    SUM = lambda do |key, rows| 
      result = 0.0
      rows.each { |r| result += r[key] }
      result
    end
    
    MIN = lambda do |key, rows| 
      result = INFINITY
      rows.each { |r| result = r[key] if r[key] < result }
      result
    end
    
    MAX = lambda do |key, rows| 
      result = -INFINITY
      rows.each { |r| result = r[key] if r[key] > result }
      result
    end
  end
  
  class Column
    attr_accessor :key
    attr_accessor :header
    attr_accessor :transformer

    def initialize(key, header, transformer)
      @key = key
      @header = header
      @transformer = transformer
    end
  end
  
  class Row
    attr_accessor :cells
    
    def initialize(table)
      @table = table
      @cells = {}
    end
    
    # get cell
    def [](key)
      @cells[key]
    end
    
    # set cell
    def []=(key, value)
      raise ColumnNotFound unless @table.columns.has_key?(key)
      @cells[key] = value
    end
  end
  
  attr_accessor :columns
  attr_accessor :rows
  
  def initialize
    @columns = {}
    @column_keys = [] # used to memorize the order of columns
    @rows = []
  end
  
  def add_column(key, header, transformer = nil)
    raise ColumnAlreadyExists if @columns.has_key?(key)
    @column_keys << key
    @columns[key] = Column.new(key, header, transformer)
  end
  
  def build_rows(items)
    items.each do |item|
      row = Row.new(self)
      @columns.each do |key, col|
        if col.transformer
          row[key] = col.transformer.call(item)
        elsif item.respond_to?(key)
          row[key] = item.send(key)
        end
      end
      yield(row, item) if block_given?
      @rows << row
    end
  end
  
  # aggregates a set of rows using aggregator functions
  def aggregate(key, rows, aggregators, group_key)
    aggregated_row = Row.new(self)
    
    aggregated_row[key] = group_key.call(rows.first[key])
    
    aggregators.each do |key, aggregator|
      aggregated_row[key] = aggregator.call(key, rows)
    end

    aggregated_row
  end
  
  # yields a grouped DataTable object
  def group_by(key, aggregators, group_key = lambda {|x| x })
    result = DataTable.new
    my_key = key
    groups = {}
    
    @rows.each do |row|
      idx = group_key.call(row[key])
      groups[idx] = groups[idx].to_a << row
    end
    
    # copy implicitly selected colums from original data table
    result.add_column(key, @columns[key].header)
    aggregators.each_key do |key|
      result.add_column(key, @columns[key].header)
    end
    
    groups.each_value do |group|
      result.rows << aggregate(my_key, group, aggregators, group_key) # pick first row # aggregate
    end
    
    result
  end
  
  def render_csv(options)
    FasterCSV.generate(options) do |csv|
      # Add headers
      headers = []
      @column_keys.each do |key|
        headers << @columns[key].header
      end
      
      csv << headers
      
      # Add data rows
      @rows.each do |row|
        row_data = []
        @column_keys.each do |key|
          row_data << row[key]
        end
        csv << row_data
      end
      
    end
  end
end


