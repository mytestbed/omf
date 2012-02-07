
require 'monitor'

require 'omf-oml'
require 'omf-oml/schema'


module OMF::OML
          
  # This table shadows an other table but keeps only the most recently added
  # row with a unique entry in the +index+ column. It will have the same
  # +schema+ as the shadowed table.
  #
  # NOTE: THe current implementation does not remove rows when they are removed
  # in the source table.
  #
  class OmlIndexedTable < OmlTable
    
    attr_reader :index_col
    attr_reader :source_table
    
    # 
    # index_col - Name of column to indexName of table
    # source_table - Table to shadow
    #
    def initialize(index_col, source_table)
      @index_col = index_col
      @source_table = source_table
      name = "#{source_table.name}+#{index_col}"
      super name, source_table.schema, {}

      @index2row = {}
      index = schema.index_for_col(index_col)
      @source_table.on_row_added(self) do |r|
        key = r[index]
        row_id = @index2row[key]
        unless row_id
          row_id = @rows.length
          @index2row[key] = row_id
        end
        @rows[row_id] = r
        _notify_row_added r
      end
    end
    
    
    # NOTE: +on_row_added+ callbacks are done within the monitor. 
    #
    def add_row(row)
      throw "Do not use"
    end
    

    
  end # OMLTable

end
