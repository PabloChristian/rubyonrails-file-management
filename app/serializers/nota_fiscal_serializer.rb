# frozen_string_literal: true

class NotaFiscalSerializer < BaseSerializer
  attributes :id, :data_emissao, :arquivo, :cancelado,
             :descricao_evento, :metadados, :nome_arquivo

  attribute :documento_cancelamento, if: -> { object.cancelado? }

  belongs_to :tipo_documento_eletronico
  belongs_to :empresa

  def descricao_evento
    return '' unless object.evento
    I18n.t('activerecord.attributes.eventos')[object.evento]
  end

  def nome_arquivo
    object.arquivo_file_name
  end

  def documento_cancelamento
    documento_por_evento(NotaFiscal::CANCELAMENTO)
  end

  def documento_por_evento(evento)
    documento = object.tenant.notas_fiscais
                      .where(chave_acesso: object.metadados['chave_acesso'])
                      .where(evento: evento).first
    return unless documento
    BaseSerializer.serialize_object(documento)
  end
end
