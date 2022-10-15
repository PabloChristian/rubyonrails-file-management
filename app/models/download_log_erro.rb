# frozen_string_literal: true

class DownloadLogErro < ApplicationRecord
  self.table_name = 'documentos_eletronicos.download_log_erros'

  attr_accessor :objeto_erro

  before_create :setar_atributos_do_objeto_erro
  after_create :atualizar_status_do_objeto_erro

  def self.registrar!(uuid, metadados, objeto_erro)
    DownloadLogErro.create!(message_broker_uuid: uuid, metadados: metadados,
                            objeto_erro: objeto_erro)
  end

  private

  def setar_atributos_do_objeto_erro
    return if objeto_erro.nil?
    self.tenant_id = objeto_erro.tenant_id
    if objeto_erro.instance_of?(DownloadTarefa)
      self.download_id = objeto_erro.download_id
      self.download_tarefa_id = objeto_erro.id
    elsif objeto_erro.instance_of?(Download)
      self.download_id = objeto_erro.id
    end
  end

  def atualizar_status_do_objeto_erro
    return if objeto_erro.nil?
    objeto_erro.registrar_falha!(metadados['mensagem'])
  end
end
