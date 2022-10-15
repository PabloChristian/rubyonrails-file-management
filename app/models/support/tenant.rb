# frozen_string_literal: true

class Tenant < ReadOnlyModel
  self.table_name = 'administrativo.tenants'
  has_many :empresas
  has_many :usuarios
  has_many :notas_fiscais, class_name: 'NotaFiscal'
  has_many :protocolos_entregas, class_name: 'ProtocoloEntrega'
  has_many :downloads
  has_many :download_tarefas
end
