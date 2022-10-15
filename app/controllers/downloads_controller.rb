# frozen_string_literal: true

class DownloadsController < ApplicationController
  before_action :filtros_nao_permitidos, :verificar_registros, only: :create

  def pesquisa
    downloads = current_tenant.downloads.nao_expirados.where(usuario_id: current_user_id)
    downloads = downloads.where(id: params[:id]) if params[:id].present?
    downloads = downloads.order('id desc').limit(15)
    json_response(downloads)
  end

  def show
    download = current_tenant.downloads.where(id: params[:id]).first
    json_response(download,
                  serializer_class: DownloadSerializer,
                  options_params: { retornar_etapas: true })
  end

  def create
    attributes = download_params.merge(usuario_id: current_user_id)
    download = current_tenant.downloads.build(attributes)
    if download.save
      json_response({ id: download.id }, serialize: false)
    else
      json_response(download.errors, status: 400)
    end
  end

  private

  def verificar_registros
    count = NotaFiscal.pesquisa_por_filtros(current_tenant.notas_fiscais, params[:filtros]).count
    message = { message: I18n.t('controllers.downloads.filtros_sem_registros') }
    json_response(message, status: 400) if count.zero?
  end

  def filtros_nao_permitidos
    metadados = params[:filtros]['metadados']
    return if metadados.nil?
    if metadados['chave_acesso'].present? ||
       metadados['codigo_nota'].present?  ||
       metadados['protocolo'].present?
      message = { message: I18n.t('controllers.downloads.filtros_nao_permitidos') }
      json_response(message, status: 400)
    end
  end

  def download_params
    params.permit(destinatarios: [:usuario_id, :email],
                  filtros: [:data_emissao_inicial, :data_emissao_final, :metadados,
                            empresas_ids: [], tipos_documentos_eletronicos_ids: [],
                            eventos_ids: []])
  end
end
