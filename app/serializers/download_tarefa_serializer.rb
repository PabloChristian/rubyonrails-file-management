# frozen_string_literal: true

class DownloadTarefaSerializer < BaseSerializer
  attributes :id, :etapa, :status, :iniciado_em, :terminado_em, :falhado_em, :label,
             :descricao_status, :duracao_processamento

  def descricao_status
    I18n.t("activerecord.attributes.download.status.#{object.status}")
  end

  def label
    case object.etapa
    when DownloadTarefa::PREPARACAO
      I18n.t('controllers.downloads.descricao_etapa_preparacao')
    when DownloadTarefa::COLETA
      object.metadados['empresa']['nome_fantasia']
    when DownloadTarefa::COMPACTACAO
      I18n.t('controllers.downloads.descricao_etapa_compactacao')
    when DownloadTarefa::UPLOAD_S3
      I18n.t('controllers.downloads.descricao_etapa_upload_s3')
    when DownloadTarefa::NOTIFICACAO
      I18n.t('controllers.downloads.descricao_etapa_notificacao')
    end
  end
end
