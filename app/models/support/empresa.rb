# frozen_string_literal: true

class Empresa < ReadOnlyModel
  self.table_name = 'cadastros.empresas'
  belongs_to :tenant
  has_many :notas_fiscais, class_name: 'NotaFiscal'
end
