# frozen_string_literal: true

class TipoDocumentoEletronico < ReadOnlyModel
  self.table_name = 'tabelas_sistema.tipos_documentos_eletronicos'
  has_many :notas_fiscais, class_name: 'NotaFiscal'
end
