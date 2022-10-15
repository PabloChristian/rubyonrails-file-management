# frozen_string_literal: true

# curl -i -u master:senha http://dev.erplinear.com.br:31672/api/queues/%2F/notas.fiscais.xml.armazenamento-error

class ProtocoloEntrega < ApplicationRecord
  self.table_name = 'documentos_eletronicos.protocolos_entregas'

  PENDENTE = 1
  ARMAZENADO = 5
  FALHA = 10
  INEXISTENTE = 99 # Status utilizado apenas para montar payload quando um protocolo não for encontrado
                   # Não é gravado no banco
  STATUS_ARRAY = [PENDENTE, ARMAZENADO, FALHA].freeze

  FALHA_VALIDACOES = 1
  FALHA_EXCECOES   = 2

  NUMERO_MAXIMO_TENTATIVAS_PROCESSAMENTO = 5

  validates :tenant_id, presence: true
  validates :cnpj_empresa_token, presence: true, length: { maximum: 14 }
  validates :status, presence: true, inclusion: { in: STATUS_ARRAY }
  validates :status_em, presence: true
  validates :payload, presence: true
  validates :tipo_falha, presence: true, if: proc { |nf| nf.status == FALHA }
  validates :mensagem_falha, presence: true, if: proc { |nf| nf.status == FALHA }

  belongs_to :tenant

  before_validation :inicializar_dados, on: :create
  # Postando na fila do rabbitmq apenas depois do commit para evitar que o Consumer tente
  # processa-la antes do registro já estar disponivel no banco de dados.
  after_commit :enfileirar_mensagem_rabbitmq, on: :create

  attr_accessor :request_params

  def armazenado?
    status == ARMAZENADO
  end

  def armazenado!(documento_id)
    attributos = {
      status: ARMAZENADO,
      status_em: Time.zone.now,
      documento_id: documento_id,
      tempo_em_fila: calcular_tempo_em_fila
    }
    update_columns(attributos)
  end

  def falha?
    status ==  FALHA
  end

  def falha_validacoes?
    tipo_falha == FALHA_VALIDACOES
  end

  def falha_excecoes?
    tipo_falha == FALHA_EXCECOES
  end

  def falhar!(mensagem, tipo)
    attributos = {
      status: FALHA,
      status_em: Time.zone.now,
      mensagem_falha: mensagem.to_json,
      tipo_falha: tipo,
      tempo_em_fila: calcular_tempo_em_fila,
      numero_tentativas: numero_tentativas + 1
    }
    update_columns(attributos)
  end

  def calcular_tempo_em_fila
    (Time.zone.now - created_at).to_i
  end

  def self.reenfileirar(quantidade_iteracoes = 0, limite_por_iteracao = 500)
    limite_por_iteracao = 500 if limite_por_iteracao > 500
    index = 1

    loop do
      tempo_inicial = Time.zone.now
      ids = []
      payloads = []
      protocolos = ProtocoloEntrega.select(:id, :payload)
                                   .where("status_em >= '2020-10-28 00:00:00'")
                                   .where('status = 1 and reprocessado is null')
                                   .order(status_em: :asc).limit(limite_por_iteracao)
      protocolos.each do |p|
        attributos = { protocolo_entrega_id: p.id, request_params: JSON.parse(p.payload) }
        ids << p.id
        payloads << attributos
      end
      NotasFiscaisXmlArmazenamentoJob.deliver!(payloads)
      ProtocoloEntrega.where('id in (?)', ids).update_all(reprocessado: 1)

      logger.error "Index: #{index} - Last: #{protocolos.last.id} - tempo: #{(Time.zone.now - tempo_inicial)}"
      break if (quantidade_iteracoes.positive? && quantidade_iteracoes == index) || protocolos.none?
      index += 1
      sleep 10
    end
  end

  private

  def inicializar_dados
    self.status_em          = Time.zone.now
    self.status             = PENDENTE
    self.payload            = request_params.to_json
    self.cnpj_empresa_token = request_params[:cnpj_empresa_token]
  end

  def enfileirar_mensagem_rabbitmq
    attributos = { protocolo_entrega_id: id, request_params: request_params }
    NotasFiscaisXmlArmazenamentoJob.deliver!(attributos)
  end
end
