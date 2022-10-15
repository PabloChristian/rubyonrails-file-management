# frozen_string_literal: true

class DownloadTarefa < ApplicationRecord
  self.table_name = 'documentos_eletronicos.download_tarefas'
  include Downloadable

  # ETAPAS
  PREPARACAO = 'preparacao'
  COLETA = 'coleta'
  COMPACTACAO = 'compactacao'
  UPLOAD_S3 = 'upload_s3'
  NOTIFICACAO = 'notificacao'
  LIMPEZA = 'limpeza'

  TIPOS_ARRAY = [PREPARACAO, COLETA, COMPACTACAO, UPLOAD_S3, NOTIFICACAO, LIMPEZA].freeze

  validates_presence_of :tenant_id
  validates :etapa, presence: true, inclusion: { in: TIPOS_ARRAY }
  validates :status, presence: true, inclusion: { in: STATUS_ARRAY }

  belongs_to :tenant, optional: true
  belongs_to :download, optional: true

  before_update :guardar_status_corrente
  after_save :sequenciar_workflow

  scope :coletas, -> { where(etapa: COLETA) }
  scope :concluidas, -> { where(status: CONCLUIDO) }

  attr_accessor :status_antes_salvar,
                :message_broker_payload,
                :possui_duplicidade_filtro

  # Page Index utilizado para controlar o inicio do processamento de coleta,
  # inicia-se com 0(zero) e é incrementado sempre que uma nova pagina é concluida.
  # O Objetivo é que, caso o processamento de coleta seja interrompido, deva se
  # iniciar novamente da pagina que parou.
  # IMPORTANTE: Utilizando o método update_column para que não seja executado validations e nem
  # callbacks. Havendo a necessidade de alteração, atentar-se para a lógica do callback
  # :sequenciar_workflow
  def atualizar_page_index!
    index = metadados['page_index']
    update_column(:metadados, metadados.merge(page_index: index + 1))
  end

  def gerar_payload_message_broker(tarefa = nil)
    tarefa = self if tarefa.nil?
    {
      message_uuid: "#{SecureRandom.uuid}-#{tarefa.id}-#{Time.zone.now}",
      tenant_id: tarefa.tenant_id,
      download_id: tarefa.download_id,
      tarefa_id: tarefa.id
    }
  end

  # Quando solicitando download com filtros exatos para de outro já existente, as tarefas de
  # COLETA E COMPACTACAO não será realizada por usar o arquivo zip que já esta pronto.
  def self.pular_etapas(download_id)
    DownloadTarefa.where(download_id: download_id).where('etapa in (?)', [COLETA, COMPACTACAO])
                  .update_all("status = '#{CONCLUIDO}', iniciado_em = '#{Time.zone.now}',
                                terminado_em = '#{Time.zone.now}'")
  end

  private

  def guardar_status_corrente
    self.status_antes_salvar = status_was.dup
  end

  # O inicio do workflow inicia no callback do model Download, aonde é adicionado
  # na fila de mensageria a tarefa de preparacao.
  def sequenciar_workflow
    return if status_antes_salvar != EM_PROCESSAMENTO || status == FALHA
    case etapa
    when PREPARACAO
      if possui_duplicidade_filtro
        adicionar_tarefa_fila_mensageria(UPLOAD_S3, DownloadXmlUploadS3Job)
      else
        adicionar_tarefa_fila_mensageria(COLETA, DownloadXmlColetaJob)
      end
    when COLETA
      adicionar_tarefa_fila_mensageria(COMPACTACAO, DownloadXmlCompactacaoJob) if compactacao_permitida?
    when COMPACTACAO
      adicionar_tarefa_fila_mensageria(UPLOAD_S3, DownloadXmlUploadS3Job)
    when UPLOAD_S3
      adicionar_mensagen_na_fila_apos_upload
    end
  end

  def adicionar_mensagen_na_fila_apos_upload
    adicionar_tarefa_fila_mensageria(NOTIFICACAO, DownloadXmlNotificacaoJob)
    adicionar_tarefa_fila_mensageria(LIMPEZA, DownloadXmlLimpezaJob)
  end

  def adicionar_tarefa_fila_mensageria(etapa, job, payload_complementar = {})
    tarefas = DownloadTarefa.where('download_id = ?', download_id).where('etapa = ?', etapa)
    payloads = tarefas.collect do |tarefa|
      payload = gerar_payload_message_broker(tarefa)
      payload.merge!(payload_complementar)
      payload.merge!(message_broker_payload) unless message_broker_payload.nil?
      payload
    end
    job.deliver!(payloads)
  end

  # So podera inserir na fila o processamento de compactacao quando todas as tarefas de coletas
  # estiverem concluidas
  # Atualmente é criado uma coleta para cada empresa passada no filtro
  def compactacao_permitida?
    return if status != CONCLUIDO
    total_coletas     = metadados['quantidade_tarefas_coleta'].to_i
    total_concluidas  = DownloadTarefa.select(:id).coletas.concluidas
                                      .where('download_id = ?', download_id).count
    total_concluidas >= total_coletas
  end
end
