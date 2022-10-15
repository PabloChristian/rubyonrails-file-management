# frozen_string_literal: true

class ReadOnlyException < StandardError; end

class ReadOnlyModel < ApplicationRecord
  before_save { |_| raise ReadOnlyException }
  before_destroy { |_| raise ReadOnlyException }
end
