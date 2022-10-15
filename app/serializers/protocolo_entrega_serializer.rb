# frozen_string_literal: true

class ProtocoloEntregaSerializer < BaseSerializer
  attributes :status, :descricao, :tempo_em_fila

  attribute :tipo_falha, if: :com_falha?
  attribute :motivo_falha, if: :com_falha?
  attribute :documento_id, if: :armazenado?

  # Quando ocorre erros internos no processamento do protocolo, haverá novas tentativas de
  # processa-lo, até que se atinja o limite estipulado. Enquanto estiver nas retentativas,
  # a consulta do protocolo irá retornar como status de PENDENTE de processamento.
  # Ao se esgotarem as tentativas, aí sim será o retornado o status de Falha.
  def status
    return ProtocoloEntrega::PENDENTE if em_tratativas_erros_internos?
    object.status
  end

  def descricao
    case object.status
    when ProtocoloEntrega::PENDENTE
      I18n.t('activerecord.attributes.protocolo_entrega.status.pendente')
    when ProtocoloEntrega::ARMAZENADO
      I18n.t('activerecord.attributes.protocolo_entrega.status.armazenado')
    when ProtocoloEntrega::FALHA
      descricao_status_falha
    end
  end

  def descricao_status_falha
    return mensagem_erro_interno if object.tipo_falha == ProtocoloEntrega::FALHA_EXCECOES
    I18n.t('activerecord.attributes.protocolo_entrega.tipo_falha.validacoes')
  end

  def mensagem_erro_interno
    if em_tratativas_erros_internos?
      I18n.t('activerecord.attributes.protocolo_entrega.status.pendente')
    else
      I18n.t('activerecord.attributes.protocolo_entrega.tipo_falha.erro_interno')
    end
  end

  def motivo_falha
    JSON.parse(object.mensagem_falha)
  end

  def tempo_em_fila
    return object.calcular_tempo_em_fila if em_tratativas_erros_internos?
    object.tempo_em_fila || object.calcular_tempo_em_fila
  end

  def com_falha?
    return false if em_tratativas_erros_internos?
    object.falha?
  end

  def armazenado?
    object.armazenado?
  end

  # Retorna true caso um determinado protocolo esteja com erros internos e ainda no processo
  # de novas tentativas de processamento
  def em_tratativas_erros_internos?
    object.status == ProtocoloEntrega::FALHA &&
      object.tipo_falha == ProtocoloEntrega::FALHA_EXCECOES &&
      object.numero_tentativas < ProtocoloEntrega::NUMERO_MAXIMO_TENTATIVAS_PROCESSAMENTO
  end
end
