# frozen_string_literal: true

class DownloadXmlLimpezaJob < DownloadXmlBaseJob
  FILA = 'download.xml.limpeza'
  to_queue FILA

  def perform
    begin
      # Pode acontecer de alguma falha ocorrer antes de ter enviado a confirmacao
      # para o rabbitmq remover a mensagem da fila "ack!", entao a mensagem sera
      # re-emfilerada! E quando voltar a executar nao tera que processar nada
      return @tarefa if @tarefa.concluida?
      @tarefa.iniciar!

      pasta = "#{Rails.application.config.download_xml_tmp_storage}#{@tarefa.download_id}"
      FileUtils.rm_rf(pasta) if Dir.exist?(pasta)

      @tarefa.concluir!
    rescue StandardError => e
      registrar_falha!(e.message, @tarefa)
      throw StandardError.new(e.message)
    end
    @tarefa
  end
end
