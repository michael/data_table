require 'json'

class DataTable

  class ColumnAlreadyExists < StandardError ; end
  class ColumnNotFound      < StandardError ; end
  
  INFINITY = 1.0 / 0
  
  module Formatters
    def self.number_to_currency(number, options = {})
        precision = options[:precision] || 2
        unit      = options[:unit] || ""
        separator = precision > 0 ? options[:separator] || "." : ""
        delimiter = options[:delimiter] || ""
        format    = options[:format] || "%u%n"
      begin
        parts = number_with_precision(number, precision).split('.')
        format.gsub(/%n/, number_with_delimiter(parts[0], delimiter) + separator + parts[1].to_s).gsub(/%u/, unit)
      rescue
        number
      end
    end
    
    def self.number_with_delimiter(number, delimiter=",", separator=".")
      begin
        parts = number.to_s.split('.')
        parts[0].gsub!(/(\d)(?=(\d\d\d)+(?!\d))/, "\\1#{delimiter}")
        parts.join separator
      rescue
        number
      end
    end
    
    def self.number_with_precision(number, precision=3)
      "%01.#{precision}f" % ((Float(number) * (10 ** precision)).round.to_f / 10 ** precision)
    rescue
      number
    end
  end
  
  module Aggregators

    SUM = lambda do |key, rows|
      rows.inject(0) { |sum, row| sum += row[key] }
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
    
    COUNT = lambda do |key, rows|
      rows.length
    end

  end
  
  class Column

    attr_accessor :key, :header, :transformer, :options

    def initialize(key, header, transformer, options)
      @key, @header, @transformer, @options = key, header, transformer, options
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
  
  def column(key, header, transformer = nil, options = {})
    raise ColumnAlreadyExists if @columns.key?(key)
    @column_keys << key
    @columns[key] = Column.new(key, header, transformer, options)
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

  def to_csv(options = { :col_sep => ',', :number_delimiter => '', :number_separator => '.', :precision => 2 })
    require 'fastercsv'
    
    csv_options = options.clone
    csv_options.delete(:number_delimiter)
    csv_options.delete(:number_separator)
    csv_options.delete(:precision)
    
    FasterCSV.generate(csv_options) do |csv|
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
          val = row[key]
          
          if val.kind_of?(Numeric)
            row_data << Formatters.number_to_currency(val, :precision => options[:precision], :separator => options[:number_separator], :delimiter => options[:number_delimiter])
          else
            row_data << val
          end
        end
        csv << row_data
      end
      
    end
  end
  
  def self.is_numeric?(i)
    i = i.to_s
    i.to_i.to_s == i || i.to_f.to_s == i
  end
  
  # export to envision collection format
  def to_collection
    # content_type :json
    result = {:items => {}, :properties => {} }
    
    # properties
    @column_keys.each do |key|
      column = columns[key]
      result[:properties][column.key] = {:name => column.header, :type => 'string', :unique => true, :meta => column.options }
    end
    
    i = 0
    
    # items
    rows.each do |row|
      item = {}
      @column_keys.each do |key|
        item[key] = row[key]
        if i == 0 # update property types based on the values
          result[:properties][key][:type] = DataTable.is_numeric?(row[key]) ? 'number' : 'string'
        end
      end
      
      i += 1
      result[:items][i.to_s] = item
    end
    
    JSON.pretty_generate(result)
  end
  
  def to_json
    # content_type :json
    result = {:items => [], :properties => {} }
    
    # properties
    @column_keys.each do |key|
      column = columns[key]
      result[:properties][column.key] = {:name => column.header}
    end
    
    rows.each do |row|
      item = {}
      @column_keys.each do |key|
        item[key] = row[key]
      end
      result[:items] << item
    end
    
    JSON.pretty_generate(result)
  end

end
