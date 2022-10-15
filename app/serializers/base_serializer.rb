# frozen_string_literal: true

class BaseSerializer < ActiveModel::Serializer
  # instance methods
  def serialize_object(obj)
    BaseSerializer.serialize_object(obj)
  end

  def serialize_resource(obj, serializer_class)
    BaseSerializer.serialize_resource(obj, serializer_class)
  end

  def each_serialize_resource(obj, serializer_class)
    BaseSerializer.each_serialize_resource(obj, serializer_class)
  end

  # class methods
  def self.serialize_resource(obj, serializer_class)
    ActiveModelSerializers::SerializableResource.new(obj, serializer: serializer_class)
  end

  def self.each_serialize_resource(obj, serializer_class)
    ActiveModelSerializers::SerializableResource.new(obj, each_serializer: serializer_class)
  end

  def self.serialize_object(obj)
    serializer_class = ActiveModel::Serializer.serializer_for(obj)
    serializer = serializer_class.new(obj)
    adapter = ActiveModelSerializers::Adapter.configured_adapter.new(serializer)
    adapter.serializable_hash
  end
end
