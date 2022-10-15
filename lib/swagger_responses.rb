# frozen_string_literal: true

module SwaggerResponses
  module CommonsErrors
    def self.extended(base)
      base.response 400 do
        key :description, 'Invalid input params'
      end
      base.response 500 do
        key :description, 'Unexpected server error'
      end
    end
  end
end
