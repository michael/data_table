require 'fastercsv'

class DataTable

  class ColumnAlreadyExists < StandardError ; end
  class ColumnNotFound      < StandardError ; end
  
  INFINITY = 1.0 / 0
  
  module Aggregators

    SUM = lambda do |key, rows|
      rows.inject(0.0) { |sum, row| sum += row[key] }
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

    attr_accessor :key, :header, :transformer

    def initialize(key, header, transformer)
      @key, @header, @transformer = key, header, transformer
    end

  end
  
  class Row

    attr_accessor :cells
    
    def initialize(table)
      @table, @cells = table, {}
    end
    
    # get cell
    def [](key)
      @cells[key]
    end
    
    # set cell
    def []=(key, value)
      raise ColumnNotFound unless @table.columns.key?(key)
      @cells[key] = value
    end

  end


  attr_accessor :rows, :columns, :source
  
  def initialize(source = [], &block)
    @source         = source
    @rows, @columns = [], {}
    @column_keys    = [] # used to memorize the order of columns
    instance_eval(&block) if block_given?
  end
  
  def column(key, header, transformer = nil)
    raise ColumnAlreadyExists if @columns.key?(key)
    @column_keys << key
    @columns[key] = Column.new(key, header, transformer)
  end

  alias :add_column :column


  def build_rows(items)
    items.each do |item|
      row = Row.new(self)
      columns.each do |key, col|
        if col.transformer
          row[key] = col.transformer.call(item)
        elsif item.respond_to?(key)
          row[key] = item.send(key)
        end
      end
      yield(row, item) if block_given?
      rows << row
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
    result = self.class.new
    my_key = key
    groups = {}
    
    rows.each do |row|
      idx = group_key.call(row[key])
      groups[idx] = groups[idx].to_a << row
    end
    
    # copy implicitly selected colums from original data table
    result.column(key, columns[key].header)
    aggregators.each_key do |key|
      result.column(key, columns[key].header)
    end
    
    groups.each_value do |group|
      result.rows << aggregate(my_key, group, aggregators, group_key) # pick first row # aggregate
    end
    
    result
  end

  def to_csv(options = { :col_sep => ','})
    FasterCSV.generate(options) do |csv|
      # Add headers
      headers = []
      @column_keys.each do |key|
        headers << columns[key].header
      end
      
      csv << headers
      
      # Add data rows
      rows.each do |row|
        row_data = []
        @column_keys.each do |key|
          row_data << row[key]
        end
        csv << row_data
      end
      
    end
  end

end
