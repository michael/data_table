require 'fastercsv'

class DataTable
  
  class ColumnAlreadyExists < StandardError ; end
  class ColumnNotFound < StandardError ; end

  class Column
    attr_accessor :key
    attr_accessor :header
    attr_accessor :transformer

    def initialize(header, transformer)
      @header = header
      @transformer = transformer
    end
  end
  
  class Row
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
  def initialize
    @columns = {}
    @column_keys = [] # used to memorize the order of columns
    @rows = []
  end
  
  def add_column(key, header, transformer = nil)
    raise ColumnAlreadyExists if @columns.has_key?(key)
    @column_keys << key
    @columns[key] = Column.new(header, transformer)
  end
  
  def build_rows!(items)
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