# frozen_string_literal: true

class Download < ApplicationRecord
  self.table_name = 'documentos_eletronicos.downloads'
  include Downloadable

  validates_presence_of :tenant_id, :usuario_id, :filtros
  validates :status, presence: true, inclusion: { in: STATUS_ARRAY }
  validates :destinatarios, presence: true
  validates :filtros, presence: true
  validate :validar_destinatarios, :validar_filtros_obrigatorios, on: :create

  belongs_to :tenant, optional: true
  belongs_to :usuario, optional: true
  has_many :tarefas, class_name: 'DownloadTarefa'

  accepts_nested_attributes_for :tarefas

  before_validation :setar_status_inicial,
                    :setar_usuario_como_destinatario, on: :create
  after_validation :setar_tarefas,
                   :setar_metadados, on: :create
  after_create :adicionar_na_fila_rabbitmq

  scope :nao_expirados, -> { where('expira_em >= ? or expira_em is null', Time.zone.now) }

  def atualizar_url_arquivo!(url)
    update_columns(
      metadados: metadados.merge(url_arquivo_zip: url),
      expira_em: Time.zone.now + 5.days
    )
  end

  def expirado?
    return false if expira_em.nil?
    expira_em < Time.zone.now
  end

  private

  def setar_status_inicial
    self.status = PENDENTE
  end

  def setar_usuario_como_destinatario
    # Obrigatoriamente o usuario que solicitou o download sera inserido como destinatario
    self.destinatarios = [] if destinatarios.nil?
    destinatarios << { 'usuario_id' => usuario_id }
  end

  # É importante que as tarefas sejam inseridas na ordem que devem ser executadas, simplesmente
  # para que no retorno para o frontEnd o order by pelo ID já ordene da forma correta, uma evolução
  # caso necessário seria inserir na tabela uma coluna ordem
  def setar_tarefas
    attributos = { tenant_id: tenant_id, status: DownloadTarefa::PENDENTE }
    tarefas << DownloadTarefa.new(attributos.merge(etapa: DownloadTarefa::PREPARACAO))
    gerar_tarefas_coleta(attributos)
    tarefas << DownloadTarefa.new(attributos.merge(etapa: DownloadTarefa::COMPACTACAO))
    tarefas << DownloadTarefa.new(attributos.merge(etapa: DownloadTarefa::UPLOAD_S3))
    tarefas << DownloadTarefa.new(attributos.merge(etapa: DownloadTarefa::NOTIFICACAO))
    tarefas << DownloadTarefa.new(attributos.merge(etapa: DownloadTarefa::LIMPEZA))
  end

  def gerar_tarefas_coleta(attributos)
    return if errors.any?
    empresas = tenant.empresas.select('id, nome_fantasia, cnpj')
                     .where('id in (?)', filtros['empresas_ids'])
    filtros['empresas_ids'].each do |id|
      attr_complementares = {
        etapa: DownloadTarefa::COLETA,
        metadados: {
          empresa: empresas.select { |e| e.id == id }.first,
          nome_tenant: tenant.nome, page_size: 200, page_index: 0,
          filtros: filtros.merge(empresas_ids: [id]),
          quantidade_tarefas_coleta: filtros['empresas_ids'].size
        }
      }
      tarefas << DownloadTarefa.new(attributos.merge(attr_complementares))
    end
  end

  def setar_metadados
    self.metadados = {
      filtros: parser_filtros({}, filtros),
      destinatarios: formatar_destinatarios
    }
  end

  # Faz parser dos filtros, formatando os IDs e datas para que possa ser exibidos na interface os
  # filtros selecionados
  def parser_filtros(parsed_hash, data)
    data.each do |k, v|
      if v.is_a?(Hash)
        parser_filtros(parsed_hash, v)
      elsif v.present?
        u_key = k.to_s.underscore
        key   = I18n.t("activerecord.attributes.notas_fiscais.filtros.#{u_key}")
        value = u_key.index('ids').present? ? descricoes_dos_ids(u_key, v) : v
        value = value.to_datetime.strftime('%d/%m/%Y %H:%M:%S') if u_key.index('data').present?
        parsed_hash.merge!(k => { label: key, value: value })
      end
    end
    parsed_hash
  end

  def descricoes_dos_ids(key, ids)
    case key.to_sym
    when :empresas_ids
      Empresa.select('nome_fantasia').where('id in (?) ', ids).collect(&:nome_fantasia)
    when :eventos_ids
      ids.collect { |id| I18n.t('activerecord.attributes.eventos')[id] }
    when :tipos_documentos_eletronicos_ids
      TipoDocumentoEletronico.select('modelo').where('id in (?)', ids).collect(&:modelo)
    end
  end

  def formatar_destinatarios
    emails = []
    usarios_ids = []
    destinatarios.each do |destinatario|
      emails << destinatario['email'] if destinatario['email'].present?
      usarios_ids << destinatario['usuario_id'] if destinatario['usuario_id'].present?
    end
    Credencial.where('usuario_id in (?)', usarios_ids).each { |c| emails << c.email }
    emails
  end

  # Validações de Regras de negócio
  def validar_destinatarios
    return if destinatarios.nil?
    destinatarios.each do |destinatario|
      usuario_id  = destinatario['usuario_id']
      email       = destinatario['email']

      errors.add(:destinatarios, i18n('destinatario_invalido')) if usuario_id.nil? && email.nil?
      errors.add(:destinatarios, i18m('destinatario_invalido')) if usuario_id.present? && email.present?
      verificar_usuario_id_destinatario(usuario_id)
      verificar_email_destinario(email)
    end
  end

  def verificar_usuario_id_destinatario(usuario_id)
    return unless usuario_id.present?
    return if usuario_id == self.usuario_id
    us = Usuario.where(id: usuario_id).first
    errors.add(:destinatarios, i18n('destinatario_invalido')) if us.nil?
  end

  def verificar_email_destinario(email)
    email_regex = /\A[\w+\-.]+@[a-z\d\-]+(\.[a-z\d\-]+)*\.[a-z]+\z/i
    return if email.nil? || (email =~ email_regex).present?
    errors.add(:destinatarios, i18n('email_destinatario_invalido', email: email))
  end

  def validar_filtros_obrigatorios
    return if filtros.nil?
    validar_filtro_empresas(filtros['empresas_ids'])
    validar_periodo(filtros)
  end

  def validar_filtro_empresas(empresas_ids)
    errors.add(:empresas_ids, i18n('emitentes_vazio')) unless empresas_ids.present?
    return unless empresas_ids.present?
    quantidade = tenant.empresas.where('id in (?)', empresas_ids).count
    errors.add(:empresas_ids, i18n('emitentes_invalidos')) if quantidade != empresas_ids.size
  end

  def validar_periodo(filtros)
    data_inicio = (filtros['data_emissao_inicial'] || '').to_date
    data_fim    = (filtros['data_emissao_final'] || '').to_date
    if data_inicio.nil? || data_fim.nil?
      errors.add(:periodo, i18n('periodo_obrigatorio'))
    elsif data_inicio > data_fim
      errors.add(:periodo, I18n.t('activerecord.errors.commons.data_termino_maior_data_inicio'))
    elsif (data_fim - data_inicio).to_i > 31
      errors.add(:periodo, I18n.t('activerecord.errors.downloads.periodo_maior_que_o_permitido'))
    end
  rescue ArgumentError
    errors.add(:periodo, I18n.t('activerecord.errors.commons.periodo_invalido'))
  end

  def i18n(chave, params = nil)
    I18n.t("activerecord.errors.downloads.#{chave}", params)
  end

  def adicionar_na_fila_rabbitmq
    payload = tarefas.select { |t| t.etapa == DownloadTarefa::PREPARACAO }
                     .collect(&:gerar_payload_message_broker)
    DownloadXmlPreparacaoJob.deliver!(payload)
  end
end
