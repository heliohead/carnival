module Carnival
  class QueryService
    
    attr_accessor :total_records
    def initialize(model, presenter, query_form)
      @model = model
      @presenter = presenter
      @query_form = query_form
      @total_records = 0
      @should_include_relation = !@model.is_a?(ActiveRecord::Relation)
    end

    def get_query
      records = records_without_pagination
      records = page_query(records)
    end

    def records_without_pagination_and_scope
      records = @model
      records = date_period_query(records)
      records = search_query(records)
      records = advanced_search_query(records)
      records = order_query(records)
      records = includes_relations(records)
    end

    def records_without_pagination
      records = records_without_pagination_and_scope
      records = scope_query(records)
    end

    def total_records
      records_without_pagination.size 
    end

    def scopes_number
      records = records_without_pagination_and_scope 
      scopes = {}
      @presenter.scopes.each do |key, index|
        rec = records
        scopes[key] = scope_query(rec, key).size
      end
      scopes
    end

    def scope_query(records, scope = @query_form.scope)
      if(scope.present? && scope.to_sym != :all)
        records = records.send(scope)
      end
      records
    end

    def date_period_query(records)
      date_filter_field = @presenter.date_filter_field
      if(date_filter_field.present? && @query_form.date_period_from.present? && @query_form.date_period_from != "" && @query_form.date_period_to.present? && @query_form.date_period_to != "")
        records = records.where("#{@presenter.table_name}.#{date_filter_field.name} between ? and ?", "#{@query_form.date_period_from} 00:00:00", "#{@query_form.date_period_to} 23:59:59")
      end
      records
    end

    def search_query(records)
      filtros = []
      if @query_form.search_term.present? and @presenter.searchable_fields.size > 0
        @presenter.searchable_fields.each do |key, field|
          filtros << "#{key.to_s} like :search"
        end
        records = includes_relations(records) if @should_include_relation
        records = records.where(filtros.join(" or "), search: "%#{@query_form.search_term}%")
      end
      records
    end

    def advanced_search_query(records)
      return records if !@query_form.advanced_search.present?
      @presenter.parse_advanced_search(records, @query_form.advanced_search)
    end

    def page_query(records)
        records = records.paginate(page: @query_form.page, per_page: @presenter.items_per_page)
    end

    def order_query(records)
      records.order("#{sort_column} #{sort_direction}")
    end

    def includes_relations(records)
      if @should_include_relation
        @presenter.join_tables.each do |relation_name|
          records = records.includes(relation_name)
        end
      end
      records
    end

    def sort_column
      column = @query_form.sort_column
      sorter = Carnival::GenericDatatable::ColumnSorterCreator.create_sorter(@presenter, column)
      sorter.build_sort_string
    end

    def sort_direction
      @query_form.sort_direction
    end

  end
end
