# frozen_string_literal: true

class DownloadXmlUploadS3Job < DownloadXmlBaseJob
  FILA = 'download.xml.upload.s3'
  to_queue FILA

  def perform
    begin
      @region         = Rails.application.config.paperclip_defaults[:s3_credentials][:s3_region]
      @bucket_name    = Rails.application.config.download_xml_bucket_name
      @arquivo_zip    = @payload[:arquivo_zip]
      @arquivo_zip_s3 = @payload[:arquivo_zip_s3]

      @download = @tarefa.download

      # Pode acontecer de alguma falha ocorrer antes de ter enviado a confirmacao
      # para o rabbitmq remover a mensagem da fila "ack!", entao a mensagem sera
      # re-emfilerada! E quando voltar a executar nao tera que processar nada
      return @tarefa if @tarefa.concluida?

      @tarefa.iniciar!

      verificar_arquivo

      link = executar
      @tarefa.message_broker_payload = { link_download: link }
      @download.atualizar_url_arquivo!(link)
      @tarefa.concluir!
    rescue StandardError => e
      registrar_falha!(e.message, @tarefa)
      throw StandardError.new(e.message)
    end
    @tarefa
  end

  def executar
    url = @arquivo_zip_s3.present? ? copiar : upload
    url
  end

  # Duplica arquivo zip já existente no s3 quando o filtro coincidir com algum outro já 
  # existente. Esta decisão de reaproveitar o zip já existente ou fazer todo o processo novamente,
  # é tomada dentro do DownloadXmlPreparacaoJob
  # Sempre irá duplicar um objeto existente por causa do tempo de expiracao.
  # Ex: imagine o arquivo            /18/Linear.zip que foi gerado a 4 dias e expira em 2 horas.
  #     será gerado a cópia do mesmo /19/Linear.zip para expirar daqui a 4 dias
  # Se simplesmente fosse enviado o link do mesmo arquivo para o usuário que solicitou agora, ele
  # não teria os 4 dias de prazo para baixar.
  def copiar
    s3        = Aws::S3::Client.new(region: @region)
    array     = @arquivo_zip_s3.split('/')
    obj_copia = array.last(2).join('/')
    obj_key   = "#{@tarefa.download_id}/#{array.last}"
    s3.copy_object(bucket: @bucket_name, copy_source: "#{@bucket_name}/#{obj_copia}", key: obj_key)
    "#{array.first(3).join('/')}/#{obj_key}"
  end

  def upload
    s3      = Aws::S3::Resource.new(region: @region)
    obj_key = "#{@tarefa.download_id}/#{@arquivo_zip.split('/').last}"
    obj     = s3.bucket(@bucket_name).object(obj_key)
    obj.upload_file(@arquivo_zip)
    obj.public_url
  end

  def verificar_arquivo
    return if @arquivo_zip.nil?
    return if File.exist?(@arquivo_zip)
    raise I18n.t('jobs.download_xml_upload_s3.arquivo_nao_encontrado', arquivo: @arquivo_zip)
  end
end
