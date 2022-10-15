# frozen_string_literal: true

module WithPagination
  PAGE_SIZE = 15
  PAGE_MAX_ALLOWED = 100

  def with_pagination(pagination, serializer_class = nil)
    pagination ||= default_pagination
    page_size = (pagination[:page_size] || PAGE_SIZE)
    page_size = PAGE_MAX_ALLOWED if page_size > PAGE_MAX_ALLOWED
    total_page = (count / page_size.to_f).ceil
    result = page(pagination[:page_index]).per(page_size)
    {
      content: {
        items: serialize(result, serializer_class),
        pagination: {
          pageIndex: pagination[:page_index],
          totalPages: total_page,
          hasNextPage: total_page > pagination[:page_index]
        }
      }
    }
  end

  def with_pagination_without_count(pagination, serializer_class = nil)
    pagination ||= default_pagination
    page_size = (pagination[:page_size] || PAGE_SIZE)
    page_size = PAGE_MAX_ALLOWED if page_size > PAGE_MAX_ALLOWED
    result = page(pagination[:page_index]).without_count.per(page_size)
    {
      content: {
        items: serialize(result, serializer_class),
        pagination: {
          pageIndex: pagination[:page_index],
          hasNextPage: result_size(result) >= page_size
        }
      }
    }
  end

  private

  def result_size(result)
    size = result.size
    return size if size.is_a? Numeric
    return size.length if size.is_a?(Hash) # Querys com group by, retornam um Hash
  end

  def serialize(result, serializer_class)
    if serializer_class.nil?
      BaseSerializer.serialize_object(result)
    else
      BaseSerializer.each_serialize_resource(result, serializer_class)
    end
  end

  def default_pagination
    {
      page_size: PAGE_SIZE,
      page_index: 1
    }
  end
end
