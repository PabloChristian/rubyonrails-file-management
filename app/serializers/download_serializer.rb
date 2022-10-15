# frozen_string_literal: true

class DownloadSerializer < BaseSerializer
  attributes :id, :status, :iniciado_em, :terminado_em, :criado_em, :falhado_em, :metadados,
             :descricao_status, :expira_em, :expirado, :duracao_processamento

  attribute :etapas, if: :retornar_etapas?

  def descricao_status
    I18n.t("activerecord.attributes.download.status.#{object.status}")
  end

  def criado_em
    object.created_at
  end

  def etapas
    etapas = {}
    tarefas = object.tarefas
                    .select('id, status, iniciado_em, terminado_em, etapa, falhado_em, metadados')
                    .where('etapa <> ?', DownloadTarefa::LIMPEZA)
                    .order(:id)
                    .group_by(&:etapa)
    tarefas.each do |k, values|
      etapas.merge!(
        k.to_s => {
          nome: I18n.t("activerecord.attributes.download.etapas.#{k}"),
          tarefas: values.map { |item| serialize_object(item) }
        }
      )
    end
    etapas
  end

  def retornar_etapas?
    instance_options[:retornar_etapas].present?
  end

  def expirado
    object.expirado?
  end
end
