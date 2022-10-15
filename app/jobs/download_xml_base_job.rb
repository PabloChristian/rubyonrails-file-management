# frozen_string_literal: true

class DownloadXmlBaseJob
  extend RabbitmqPublisher
  attr_accessor :tenant_id, :tarefa_id, :download_id

  def initialize(payload)
    @payload      = payload
    @tenant_id    = payload[:tenant_id]
    @tarefa_id    = payload[:tarefa_id]
    @download_id  = payload[:download_id]

    # Usado find de proposito para gerar exception caso não encontre o registo
    @tenant   = Tenant.find(tenant_id)
    @tarefa   = @tenant.download_tarefas.find(tarefa_id)
  end

  def registrar_falha!(mensagem, objeto_erro = nil)
    uuid = @payload[:message_uuid]
    metadados = {
      mensagem: mensagem,
      payload_message_broker: @payload,
      local_erro: to_s
    }
    DownloadLogErro.registrar!(uuid, metadados, objeto_erro)
  end
end
