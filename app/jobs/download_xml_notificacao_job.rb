# frozen_string_literal: true

class DownloadXmlNotificacaoJob < DownloadXmlBaseJob
  FILA = 'download.xml.notificacao'
  to_queue FILA

  def perform
    begin
      @download = @tarefa.download
      # Pode acontecer de alguma falha ocorrer antes de ter enviado a confirmacao
      # para o rabbitmq remover a mensagem da fila "ack!", entao a mensagem sera
      # re-emfilerada! E quando voltar a executar nao tera que processar nada
      return @tarefa if @tarefa.concluida?

      @tarefa.iniciar!

      montar_destinatarios
      enviar_email

      @download.concluir! if @download.em_processamento?
      @tarefa.concluir!
    rescue StandardError => e
      @download.concluir! if @download.em_processamento?
      registrar_falha!(e.message, @tarefa)
      throw StandardError.new(e.message)
    end
    @tarefa
  end

  def enviar_email
    base_url      = ENV.fetch('LINEAR_SDK_URL_BASE_NOTIFICACOES') { 'http://127.0.0.1' }
    uri           = URI.parse("#{base_url}/notificacoes/email")
    http          = Net::HTTP.new(uri.host, uri.port)
    header        = { 'Content-Type': 'application/json' }
    request       = Net::HTTP::Post.new(uri.request_uri, header)
    request.body  = email_body

    response = http.request(request)
    return if response.code.to_i == 200
    raise I18n.t('jobs.download_xml_notificacao.email_nao_enviado')
  end

  def montar_destinatarios
    @emails = []
    usarios_ids = []
    @tarefa.download.destinatarios.each do |destinatario|
      @emails << destinatario['email'] if destinatario['email'].present?
      usarios_ids << destinatario['usuario_id'] if destinatario['usuario_id'].present?
    end
    Credencial.where('usuario_id in (?)', usarios_ids).each { |c| @emails << c.email }
    raise I18n.t('jobs.download_xml_notificacao.destinatarios_invalidos') if @emails.size.zero?
  end

  def email_body
    link = @payload[:link_download]
    {
      de: 'no-reply@linearsistemas.com.br',
      para: @emails,
      assunto: I18n.t('jobs.download_xml_notificacao.email.assunto'),
      mensagem: I18n.t('jobs.download_xml_notificacao.email.mensagem'),
      modoHtml: true,
      modelo: 1,
      variaveis: {
        titulo: I18n.t('jobs.download_xml_notificacao.email.titulo'),
        'botao-texto': I18n.t('jobs.download_xml_notificacao.email.botao'),
        'botao-url': link,
        rodape: 'Até breve,<br/>Equipe Linear Web Team'
      }
    }.to_json
  end
end