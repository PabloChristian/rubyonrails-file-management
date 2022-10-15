# frozen_string_literal: true

class Usuario < ReadOnlyModel
  self.table_name = 'seguranca.usuarios'

  has_many :downloads
end
