# frozen_string_literal: true

module Downloadable
  extend ActiveSupport::Concern
  include ActionView::Helpers::DateHelper

  # STATUS
  PENDENTE = 'pendente'
  EM_PROCESSAMENTO = 'processamento'
  FALHA = 'falha'
  CONCLUIDO = 'concluido'

  STATUS_ARRAY = [PENDENTE, EM_PROCESSAMENTO, FALHA, CONCLUIDO].freeze

  def iniciar!
    attributos = { status: EM_PROCESSAMENTO, iniciado_em: Time.zone.now }
    update_attributes!(attributos)
  end

  def concluir!
    attributos = {
      status: CONCLUIDO,
      terminado_em: Time.zone.now,
      falhado_em: nil,
      mensagem_falha: nil
    }
    update_attributes!(attributos)
  end

  def registrar_falha!(mensagem)
    # So registra falha caso ainda nao tenha sido concluido
    return if concluida?
    attributos = {
      status: FALHA,
      falhado_em: Time.zone.now,
      mensagem_falha: mensagem
    }
    attributos.merge!(numero_tentativas: numero_tentativas + 1) if instance_of?(DownloadTarefa)
    update_attributes!(attributos)
  end

  def pendente?
    status == PENDENTE
  end

  # mantem a semantica quando usando instancia de download.concluido?
  def concluido?
    status == CONCLUIDO
  end

  # mantem a semantica quando usando instancia de download_tarefa.concluida?
  def concluida?
    status == CONCLUIDO
  end

  def em_processamento?
    status == EM_PROCESSAMENTO
  end

  def duracao_processamento
    return nil unless iniciado_em.present? && terminado_em.present?
    distance_of_time_in_words(iniciado_em, terminado_em, include_seconds: true)
  end
end
