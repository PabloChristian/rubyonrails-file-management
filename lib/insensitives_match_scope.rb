# frozen_string_literal: true

module InsensitivesMatchScope
  def self.included(base)
    base.scope :insensitives_match, (lambda do |field, value, options = {}|
      object_class = options[:model_name].constantize if options[:model_name]
      object_class ||= base
      where(object_class.arel_table[field].matches("%#{value}%")) if value
    end)
  end
end
