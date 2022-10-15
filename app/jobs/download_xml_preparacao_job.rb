# frozen_string_literal: true

class DownloadXmlPreparacaoJob < DownloadXmlBaseJob
  FILA = 'download.xml.preparacao'
  to_queue FILA

  def perform
    begin
      sleep 1
      @download = @tarefa.download

      # Pode acontecer de alguma falha ocorrer antes de ter enviado a confirmacao
      # para o rabbitmq remover a mensagem da fila "ack!", entao a mensagem sera
      # re-emfilerada! E quando voltar a executar nao tera que processar nada
      return @tarefa if @tarefa.concluida?

      @download.iniciar! if @download.pendente?
      @tarefa.iniciar!

      processar

      if @url_arquivo_zip.present?
        @tarefa.possui_duplicidade_filtro = true
        @tarefa.message_broker_payload = { arquivo_zip_s3: @url_arquivo_zip }
      end
      @tarefa.concluir!
    rescue StandardError => e
      registrar_falha!(e.message, @tarefa)
      throw StandardError.new(e.message)
    end
    @tarefa
  end

  def processar
    # Com a execução do caso #024897, não mais poderá verificar a similaridade dos filtros
    # código poderá ser removido no futuro
    # verificar_download_similar
  end

  def verificar_download_similar
    download = @tenant.downloads.where(filtros: @download.filtros).where('id <> ? ', @download.id)
                      .where('expira_em > ? and status = ? ', Time.zone.now, Download::CONCLUIDO).first
    return if download.nil?

    # Atualiza etapas para concluido
    @url_arquivo_zip = download.metadados['url_arquivo_zip']
    DownloadTarefa.pular_etapas(@download.id)
  end
end
