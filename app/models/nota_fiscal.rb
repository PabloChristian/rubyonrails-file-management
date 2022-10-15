# frozen_string_literal: true

class NotaFiscal < ApplicationRecord
  include NotaFiscalNfe
  include FiltroPorPeriodoScope
  extend WithPagination
  self.table_name = 'documentos_eletronicos.notas_fiscais'

  # Modelos
  NFE = '55'
  NFCE = '65'
  MODELOS = [NFE, NFCE].freeze

  # Eventos enviado no payload
  AUTORIZACAO = 1
  CANCELAMENTO = 2
  INUTILIZACAO = 3
  CONTINGENCIA = 4
  EVENTOS = [AUTORIZACAO, CANCELAMENTO, INUTILIZACAO, CONTINGENCIA].freeze

  validates :tenant_id, presence: true
  validates :empresa_id, presence: true
  validates :data_emissao, presence: true
  validates :tipo_documento_eletronico_id, presence: true
  validates :evento, presence: true, numericality: { only_integer: true }, inclusion: { in: EVENTOS }
  validates :conteudo_xml, presence: true
  validates :serie, presence: true, length: { maximum: 3 }, numericality: { only_integer: true }
  validates :modelo, presence: true, length: { is: 2 }, numericality: { only_integer: true }
  validates :chave_acesso, presence: true, length: { is: 44 },
                           unless: proc { evento == INUTILIZACAO }
  validates :protocolo, presence: true, length: { is: 15 }, unless: proc { evento == CONTINGENCIA }
  validates :codigo_nota, presence: true, length: { minimum: 8, maximum: 9 },
                          unless: proc { evento == INUTILIZACAO }
  validates :cpf_cliente, length: { is: 11 }, numericality: { only_integer: true },
                          if: proc { cpf_cliente.present? }
  validates :cnpj_cliente, length: { is: 14 }, numericality: { only_integer: true },
                           if: proc { cnpj_cliente.present? }
  validates :cnpj_emitente, presence: true, length: { is: 14 }, numericality: { only_integer: true }
  validates :nome_arquivo, presence: true

  belongs_to :tenant
  belongs_to :empresa
  belongs_to :tipo_documento_eletronico

  before_validation :anexar_arquivo
  before_validation :setar_tipo_documento_eletronico, on: :create
  before_validation :setar_registro_completo, on: :create # Temporario
  after_create :setar_documento_referenciado_como_cancelado!

  after_save :deletar_arquivo_temporario,
             :setar_protocolo_entrega_como_processado!

  after_rollback :deletar_arquivo_temporario

  scope :pesquisar_campos, lambda { |value|
    where('metadados @> ?', { chave_acesso: value }.to_json)
      .or(where('metadados @> ?', { cnpj_emitente: value }.to_json))
      .or(where('metadados @> ?', { modelo: value }.to_json))
      .or(where('metadados @> ?', { cnpj_cliente: value }.to_json))
      .or(where('metadados @> ?', { cpf_cliente: value }.to_json))
      .or(where('metadados @> ?', { codigo_nota: value }.to_json))
      .or(where('metadados @> ?', { protocolo: value }.to_json))
      .or(where('metadados @> ?', { serie: value }.to_json))
  }

  scope :pesquisar_por_metadados, lambda { |metadados|
    metadados.delete_if { |_, value| value.to_s.empty? } if metadados.present?
    where('metadados @> ?', metadados.to_json) if metadados.present?
  }

  attr_accessor :conteudo_xml,
                :nome_arquivo,
                :documento_referenciado,
                :arquivo_upload_path,
                :xml_autorizacao,
                :xml_cancelamento,
                :xml_inutilizacao,
                :xml_contingencia,
                :cnpj_empresa_token, # Utilizado para validar se o CNPJ do emitente e o mesmo do token
                :chave_acesso_contingencia,
                :protocolo_entrega

  attr_accessor :tempo_arquivo, :tempo_upload, :tempo_delete_arquivo, :tempo_update_doc_Ref

  file_path = 'tenants/:codigo_tenant/documentos_eletronicos/:modelo/:mes_ano_emissao/:id/:basename.:extension'
  has_attached_file :arquivo, path: file_path

  do_not_validate_attachment_file_type :arquivo
  validates_attachment_size :arquivo,
                            in: 0.kilobytes..500.kilobytes,
                            message: I18n.t('activerecord.errors.commons.imagens.limite_500_kb')
  validates_attachment_presence :arquivo

  before_post_process do
    @upload_start = Time.zone.now
  end

  after_post_process do
    self.tempo_upload = (Time.zone.now - @upload_start)
  end

  def mes_ano_emissao
    return if data_emissao.nil?
    data_emissao.strftime('%Y%m')
  end

  def self.pesquisa_por_filtros(query, params)
    tipo = params[:tipos_documentos_eletronicos_ids]
    query = query.where('empresa_id in (?)', params[:empresas_ids]) if params[:empresas_ids].present?
    query = query.where('tipo_documento_eletronico_id in ( ? )', tipo) if tipo.present?
    query = query.where('evento in ( ? )', params[:eventos_ids]) if params[:eventos_ids].present?
    query = query.por_periodo(:data_emissao, params) if params[:data_emissao_inicial].present?
    query = query.pesquisar_por_metadados(params[:metadados])
    query
  end

  private

  def anexar_arquivo
    return unless nome_arquivo
    time_inicio = Time.zone.now

    self.arquivo_upload_path = "tmp/#{nome_arquivo}"
    arquivo_upload = File.open(arquivo_upload_path, 'w')
    arquivo_upload.write(conteudo_xml)
    arquivo_upload.close
    self.arquivo = File.open(arquivo_upload_path)

    self.tempo_arquivo = (Time.zone.now - time_inicio) if ENV['DEBUG_RAILS_ATIVO']
  end

  def setar_tipo_documento_eletronico
    return if modelo.nil?
    tipo = TipoDocumentoEletronico.select(:id).where(modelo: modelo).take
    self.tipo_documento_eletronico_id = tipo&.id
  end

  def setar_documento_referenciado_como_cancelado!
    return unless xml_cancelamento && documento_referenciado
    inicio = Time.zone.now
    documento_referenciado.update_column('cancelado', true)
    self.tempo_update_doc_Ref = (Time.zone.now - inicio)
  end

  def deletar_arquivo_temporario
    inicio = Time.zone.now
    return if arquivo_upload_path.nil?
    File.delete(arquivo_upload_path) if File.exist?(arquivo_upload_path)
    self.tempo_delete_arquivo = (Time.zone.now - inicio)
  end

  # Temporário:: Deverá ser removido após processados os registros antigos
  def setar_registro_completo
    self.registro_completo = true
  end

  def setar_protocolo_entrega_como_processado!
    return if protocolo_entrega.nil?
    protocolo_entrega.armazenado!(id)
  end
end
