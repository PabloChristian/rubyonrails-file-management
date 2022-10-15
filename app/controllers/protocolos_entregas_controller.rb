# frozen_string_literal: true

class ProtocolosEntregasController < ApplicationController
  before_action :carregar_protocolo, only: [:consultar]

  def consultar
    json_response(@protocolo)
  end

  def limpar_processados
    status = [ProtocoloEntrega::ARMAZENADO, ProtocoloEntrega::FALHA]
    linhas_afetadas = ProtocoloEntrega.where(status: status)
                                      .where('status_em <= ?', Time.zone.now - 120.days)
                                      .delete_all
    json_response(linhas_afetadas, serialize: false)
  end

  def reenfileirar
    Thread.new do
      quantidade_iteracoes = params[:quantidade_iteracoes] || 40
      ProtocoloEntrega.reenfileirar(quantidade_iteracoes, params[:limite_por_iteracao])
    end
    render :ok
  end

  private

  def carregar_protocolo
    campos = [:id, :tenant_id, :status, :status_em, :tipo_falha, :mensagem_falha,
              :documento_id, :tempo_em_fila, :created_at, :numero_tentativas]
    @protocolo = ProtocoloEntrega.select(campos).where(id: params[:id]).first

    if @protocolo.nil?
      json_response(json_inexistencia, serialize: false)
    elsif @protocolo.tenant_id != current_tenant.id
      json_response({ message: I18n.t('controllers.protocolos_entregas.consulta_negada') },
                    status: 400)
    end
  end

  def json_inexistencia
    {
      status: ProtocoloEntrega::INEXISTENTE,
      descricao: I18n.t('activerecord.attributes.protocolo_entrega.status.inexistente')
    }
  end
end
