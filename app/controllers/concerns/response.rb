# frozen_string_literal: true

module Response
  def json_response(object, options = {})
    status          = options[:status] || :ok
    serialize       = true
    serialize       = false if options[:serialize] == false
    render_include  = options[:include]
    options_params  = options[:options_params] || {}

    if options[:each_serializer_class].present?
      with_each_serializer(object, options[:each_serializer_class], options_params)
    elsif options[:serializer_class].present?
      with_serializer(object, options[:serializer_class], options_params)
    else
      content = object
      content = { content: serialize ? BaseSerializer.serialize_object(object) : object } if status == :ok
      args = { json: content, status: status, include: render_include }.merge(options_params)
      render args
    end
  end

  private

  def with_each_serializer(object, serializer_class, options_params)
    args = { json: object, each_serializer: serializer_class, adapter: :json, root: 'content' }
    render args.merge(options_params)
  end

  def with_serializer(object, serializer_class, options_params)
    args = { json: object, serializer: serializer_class, adapter: :json, root: 'content' }
    render args.merge(options_params)
  end
end
