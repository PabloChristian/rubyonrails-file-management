# frozen_string_literal: true

class DownloadXmlColetaJob < DownloadXmlBaseJob
  FILA = 'download.xml.coleta'
  to_queue FILA

  def perform
    begin
      sleep 1
      region        = Rails.application.config.paperclip_defaults[:s3_credentials][:s3_region]
      @nome_bucket  = Rails.application.config.paperclip_defaults[:s3_credentials][:bucket]
      @s3_resource  = Aws::S3::Resource.new(region: region)
      @filtros      = @tarefa.metadados['filtros']

      # Converte keys do hash para symbol para manter compatibilidade com o metodo
      # pesquisar_por_filtros usado logo abaixo
      @filtros = @filtros.inject({}) { |memo, (k, v)| memo[k.to_sym] = v; memo }

      # Pode acontecer de alguma falha ocorrer antes de ter enviado a confirmacao
      # para o rabbitmq remover a mensagem da fila "ack!", entao a mensagem sera
      # re-emfilerada! E quando voltar a executar nao tera que processar nada
      return @tarefa if @tarefa.concluida?

      # @download.iniciar! if @download.pendente?
      @tarefa.iniciar!

      processar

      @tarefa.message_broker_payload = { pasta_zip: @pasta_processamento }
      @tarefa.concluir!
    rescue StandardError => e
      registrar_falha!(e.message, @tarefa)
      throw StandardError.new(e.message)
    end
    @tarefa
  end

  def processar
    gerar_caminho_base_das_pastas
    criar_pastas_para_copia_dos_arquivos
    copiar_arquivos
  end

  def copiar_arquivos
    page_size = @tarefa.metadados['page_size'].to_i
    index = @tarefa.metadados['page_index'].to_i
    loop do
      notas = NotaFiscal.select('id, data_emissao, metadados, arquivo_file_name, tenant_id, modelo')
                        .pesquisa_por_filtros(@tenant.notas_fiscais, @filtros)
                        .order(:id).limit(page_size).offset(index * page_size)
      notas.each do |nota|
        obj = @s3_resource.bucket(@nome_bucket).object(nota.arquivo.path)
        obj.get(response_target: file_path(nota))
      end
      @tarefa.atualizar_page_index!
      index += 1
      break if notas.size.zero?
    end
  end

  def gerar_caminho_base_das_pastas
    base_path   = Rails.application.config.download_xml_tmp_storage
    metadados   = @tarefa.metadados
    nome_tenant = metadados['nome_tenant'].gsub(' ', '_')
    cnpj        = metadados['empresa']['cnpj']
    # TODO: ver sobre colocar o prefixo em variaveis de ambiente
    @pasta_processamento = "#{base_path}#{@tarefa.download_id}/#{nome_tenant}"
    @pasta_empresa       = "#{base_path}#{@tarefa.download_id}/#{nome_tenant}/#{cnpj}/"
  end

  def criar_pastas_para_copia_dos_arquivos
    data_inicio = @filtros[:data_emissao_inicial].to_date
    data_final  = @filtros[:data_emissao_final].to_date
    meses       = (data_inicio..data_final).collect { |d| formatar_mes_ano(d) }.uniq
    @pastas     = {}

    meses.each do |mes|
      pasta = "#{@pasta_empresa}#{mes}/"
      FileUtils.mkdir_p(pasta) unless Dir.exist?(pasta)
      @pastas.merge!(mes => pasta)
    end
  end

  def file_path(nota)
    mes_ano = formatar_mes_ano(nota.data_emissao)
    "#{@pastas[mes_ano]}#{formatar_nome_arquivo(nota)}"
  end

  def formatar_mes_ano(data)
    data.strftime('%b_%Y')
  end

  def formatar_nome_arquivo(nota)
    # A tratativas seguinte e devido o formato em que a Linear grava os xmls de NFCe:
    # NFe31190305800348000187650800000177801000022804-procNFe.xml.001
    # Remove a extensao do arquivo e o '.xml'
    nome = nota.arquivo_file_name[0, nota.arquivo_file_name.length - 4].gsub('.xml', '')

    # Adiciona no nome do arquivo, o id unico do registro no banco de dados, para evitar
    # para a pasta que sera compactada
    nome += "_#{nota.id}.xml"
    nome
  end
end
