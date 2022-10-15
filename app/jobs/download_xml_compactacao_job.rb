# frozen_string_literal: true

class DownloadXmlCompactacaoJob < DownloadXmlBaseJob
  FILA = 'download.xml.compactacao'
  to_queue FILA

  def perform
    begin
      # Pode acontecer de alguma falha ocorrer antes de ter enviado a confirmacao
      # para o rabbitmq remover a mensagem da fila "ack!", entao a mensagem sera
      # re-emfilerada! E quando voltar a executar nao tera que processar nada
      return @tarefa if @tarefa.concluida? || @tarefa.em_processamento?

      @tarefa.iniciar!

      verficar_pasta
      compactar_arquivo

      @tarefa.message_broker_payload = { arquivo_zip: @arquivo_zip }
      @tarefa.concluir!
    rescue StandardError => e
      registrar_falha!(e.message, @tarefa)
      throw StandardError.new(e.message)
    end
    @tarefa
  end

  def compactar_arquivo
    zip = ZipFileGenerator.new(@pasta_zip, @arquivo_zip)
    zip.write

    return if File.exist?(@arquivo_zip)
    raise I18n.t('jobs.download_xml_compactacao.arquivo_nao_gerado', arquivo: @arquivo_zip)
  end

  def verficar_pasta
    @pasta_zip   = "#{@payload[:pasta_zip]}/"
    @arquivo_zip = "#{@payload[:pasta_zip]}.zip"

    # Deleta o arquivo caso já exista
    File.delete(@arquivo_zip) if File.exist?(@arquivo_zip)
    return if Dir.exist?(@pasta_zip)
    raise I18n.t('jobs.download_xml_compactacao.pasta_nao_encontrada', pasta: @pasta_zip)
  end
end
