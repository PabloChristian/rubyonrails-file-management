# frozen_string_literal: true

class NotasFiscaisController < ApplicationController
  before_action :carrega_nota_fiscal, only: %i[show destroy]
  before_action :verificar_filtro, only: %i[recuperar_conteudo]
  before_action :verificar_filtro_por_data,
                :verifica_tenant_linear,
                :verificar_quantidade_dias_filtro_por_data, only: :resumo_por_data
  before_action :verificar_filtro_por_data_emissao, only: :pesquisa
  before_action :localizar_contingencia_para_substituicao, only: :substituir_contingencia

  def pesquisa
    notas    = current_tenant.notas_fiscais
    conteudo = params[:conteudo]
    notas = if conteudo.present?
              notas.pesquisar_campos(params[:conteudo])
            else
              NotaFiscal.pesquisa_por_filtros(notas, params)
            end
    notas = notas.includes(:empresa, :tipo_documento_eletronico)
                 .order('data_emissao desc').limit(50)
    json_response(notas)
  end

  def create
    if params[:async] == true
      start_at = Time.zone.now
      criar_protocolo_entrega(notas_fiscais_params)
      logger.error ActiveSupport::LogSubscriber.new.send(:color, "TenantId: #{current_tenant.id}", :red)
      logger.error ActiveSupport::LogSubscriber.new.send(:color, "Time: #{Time.zone.now - start_at}", :red)
      logger.error ActiveSupport::LogSubscriber.new.send(:color, '-' * 80, :red)
    else
      start_at = Time.zone.now
      criar_nota_fiscal
      logger.error ActiveSupport::LogSubscriber.new.send(:color, "TenantId: #{current_tenant.id}", :blue)
      logger.error ActiveSupport::LogSubscriber.new.send(:color, "Time: #{Time.zone.now - start_at}", :blue)
      logger.error ActiveSupport::LogSubscriber.new.send(:color, '-' * 80, :blue)
    end
  end

  def substituir_contingencia
    start_at = Time.zone.now
    async = false
    presente = false
    criar_nota = false

    if params[:async] == true
      async = true
      criar_protocolo_entrega(contingencia_params.merge(substituicao_contingencia: true))
    elsif @contingencia.present?
      presente = true      
      @contingencia.cnpj_empresa_token = current_cnpj_empresa
      if @contingencia.update_attributes(contingencia_params)
        json_response({ id: @contingencia.id }, serialize: false)
      else
        json_response(@contingencia.errors, status: 400)
      end
    else
      criar_nota = true
      criar_nota_fiscal
    end
    logger.error ActiveSupport::LogSubscriber.new.send(:color, "TenantId: #{current_tenant.id}", :green)
    logger.error ActiveSupport::LogSubscriber.new.send(:color, "Time: #{Time.zone.now - start_at}", :green)
    logger.error ActiveSupport::LogSubscriber.new.send(:color, "Async: #{async} | Present: #{presente} | Criar Nota: #{criar_nota}", :green)
    logger.error ActiveSupport::LogSubscriber.new.send(:color, '-' * 80, :green)
  end

  def show
    json_response(@nota_fiscal)
  end

  # Ainda se precisa discutir sobre o processo de exclusao de xmls por se tratar de uma
  # operacao extremamente cautelosa e arriscada
  # def destroy
  #   @nota_fiscal.destroy
  #   json_response({ id: @nota_fiscal.id }, serialize: false)
  # end

  def eventos
    eventos = NotaFiscal::EVENTOS.collect do |de|
      { id: de, descricao: I18n.t('activerecord.attributes.eventos')[de] }
    end
    json_response(eventos, serialize: false)
  end

  def recuperar_conteudo
    notas = current_tenant.notas_fiscais
    notas = if params[:id].present?
              notas.where(id: params[:id])
            else
              notas.pesquisar_por_metadados(params[:metadados])
            end
    # So para garantir que não irá trazer muitos registros caso de algum furo no filtro.
    # 2 é considerando um documento com Autorização e Cancelamento
    notas = notas.limit(2)
    json_response(notas, each_serializer_class: NotaFiscalConteudoXmlSerializer)
  end

  def resumo_por_data
    result = NotaFiscal.select('count(notas_fiscais.id) as quantidade, tenants.nome as nome_tenant,
                          tenants.cnpj')
                       .joins(:tenant)
                       .por_periodo(:data_emissao, params)
                       .por_periodo(:data_cadastro, params, :created_at)
    result = result.where('tenants.cnpj in (?)', params[:cnpjs_tenant]) if params[:cnpjs_tenant]
    result = result.group('tenants.nome, tenants.cnpj')
                   .order('tenants.nome')
                   .with_pagination_without_count(params[:pagination], NotaFiscalResumoPorDataSerializer)
    render json: result
  end

  private

  def criar_protocolo_entrega(request_params)
    attributes = request_params.merge!(
      cnpj_empresa_token: current_cnpj_empresa,
      tenant_id: current_tenant.id
    )
    protocolo = current_tenant.protocolos_entregas.build(request_params: attributes)
    if protocolo.save
      json_response({ protocolo: protocolo.id.to_s }, serialize: false)
    else
      json_response(protocolo.errors, status: 400)
    end
  end

  def criar_nota_fiscal
    hora_inicio = Time.zone.now

    nota_fiscal = current_tenant.notas_fiscais.new(notas_fiscais_params)
    nota_fiscal.cnpj_empresa_token = current_cnpj_empresa
    if nota_fiscal.save
      # inicio log
      if ENV['DEBUG_RAILS_ATIVO'] && ['todos', 'sucesso'].include?(ENV['DEBUG_TIPO_LOG'])
        elapse_time = (Time.zone.now - hora_inicio)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, '-' * 80, :blue)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Sucesso         => #{elapse_time}", :blue)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: TenantID        => #{current_tenant.id}", :blue)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: EmpresaToken    => #{current_cnpj_empresa}", :blue)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: CnpjEmitente    => #{nota_fiscal.cnpj_emitente}", :blue)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Chave Acesso    => #{nota_fiscal.chave_acesso}", :blue)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Inicio/Fim      => #{hora_inicio} -> #{Time.zone.now}", :blue)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Arquivo Temp    => #{nota_fiscal.tempo_arquivo}", :blue)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Upload S3       => #{nota_fiscal.tempo_upload}", :blue)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Delete Arquivo  => #{nota_fiscal.tempo_delete_arquivo}", :blue)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Update Ref      => #{nota_fiscal.tempo_update_doc_Ref}", :blue)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, '-' * 80, :blue)
      end
      # fim log
      json_response({ id: nota_fiscal.id }, serialize: false)
    else
      # inicio log
      if ENV['DEBUG_RAILS_ATIVO'] && ['todos', 'falha'].include?(ENV['DEBUG_TIPO_LOG'])
        elapse_time = (Time.zone.now - hora_inicio)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, '-' * 80, :red)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Falha           => #{elapse_time}", :red)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: TenantID        => #{current_tenant.id}", :red)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: EmpresaToken    => #{current_cnpj_empresa}", :red)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: CnpjEmitente    => #{nota_fiscal.cnpj_emitente}", :red)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Inicio/Fim      => #{hora_inicio} -> #{Time.zone.now}", :red)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Chave Acesso    => #{nota_fiscal.chave_acesso}", :red)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Nome Arquivo    => #{nota_fiscal.nome_arquivo}", :red)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Evento          => #{nota_fiscal.evento}", :red)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Arquivo Temp    => #{nota_fiscal.tempo_arquivo}", :red)
        logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Inconsistencias => #{nota_fiscal.errors.full_messages}", :red)
        unless nota_fiscal.cnpj_emitente.present?
          logger.error ActiveSupport::LogSubscriber.new.send(:color, ":: Conteudo        => #{nota_fiscal.conteudo_xml}", :red)
        end
        logger.error ActiveSupport::LogSubscriber.new.send(:color, '-' * 80, :red)
      end
      # fim log
      json_response(nota_fiscal.errors, status: 400)
    end
  end

  def notas_fiscais_params
    params.permit(:nome_arquivo, :conteudo_xml, :evento, :async)
  end

  def contingencia_params
    params.permit(:nome_arquivo, :conteudo_xml, :evento, :chave_acesso_contingencia, :async)
  end

  def carrega_nota_fiscal
    @nota_fiscal = current_tenant.notas_fiscais.find(params[:id])
  end

  def verificar_filtro
    return if params[:id].present?
    metadados = params[:metadados]
    metadados = metadados.delete_if { |_, value| value.to_s.empty? } if metadados.present?

    json = { message: I18n.t('controllers.notas_fiscais.filtro_invalido') }
    json_response(json, status: 400, serialize: false) if metadados.nil? || metadados.empty?
  end

  def verificar_filtro_por_data
    return if params[:data_emissao_inicial].present? && params[:data_emissao_final].present?
    return if params[:data_cadastro_inicial].present? && params[:data_cadastro_final].present?
    json = { message: I18n.t('controllers.notas_fiscais.filtro_invalido_datas') }
    json_response(json, status: 400, serialize: false)
  end

  def verificar_filtro_por_data_emissao
    return if params[:conteudo].present?
    return if params[:data_emissao_inicial].present? && params[:data_emissao_final].present?
    json = { message: I18n.t('controllers.notas_fiscais.filtro_data_emissao_invalida') }
    json_response(json, status: 400, serialize: false)
  end

  def verificar_quantidade_dias_filtro_por_data
    menssagem = { message: I18n.t('controllers.notas_fiscais.periodo_superior_31_dias') }
    inicio = params[:data_emissao_inicial]
    fim    = params[:data_emissao_final]
    if inicio.present? && fim.present? && (DateTime.parse(fim) - DateTime.parse(inicio)) > 31
      json_response(menssagem, status: 400, serialize: false)
    end

    inicio = params[:data_cadastro_inicial]
    fim    = params[:data_cadastro_final]
    if inicio.present? && fim.present? && (DateTime.parse(fim) - DateTime.parse(inicio)) > 31
      json_response(menssagem, status: 400, serialize: false)
    end
  end

  # TODO: Após rotas deste serviço forem adicionadas no controle de permissões que é feito no serviço
  # Auth, deverá remover estar verificação.
  def verifica_tenant_linear
    return if tenant_linear?
    json = { message: I18n.t('controllers.errors.operacao_nagada') }
    json_response(json, status: 400, serialize: false)
  end

  # TODO: Quando todos os clientes já estiverem usando o assincrono, este codigo deverá ser
  # removido
  def localizar_contingencia_para_substituicao
    return if contingencia_params[:async].present?
    chave = contingencia_params[:chave_acesso_contingencia]

    if chave.present?
      @contingencia = current_tenant.notas_fiscais
                                    .where(chave_acesso: chave, evento: NotaFiscal::CONTINGENCIA)
                                    .take
    else
      mensagem = I18n.t('controllers.notas_fiscais.chave_acesso_contingencia_nao_informada')
      json_response({ message: mensagem }, status: 400, serialize: false)
    end
  end
end
