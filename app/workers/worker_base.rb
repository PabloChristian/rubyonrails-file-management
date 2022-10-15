# frozen_string_literal: true

class WorkerBase
  def decode_data(payload)
    data = ActiveSupport::JSON.decode(payload)
    data = data.inject({}) { |memo, (k, v)| memo[k.to_sym] = v; memo }
    data
  end
end
