# frozen_string_literal: true

class NotasFiscaisXmlArmazenamentoJob
  extend RabbitmqPublisher

  FILA                  = 'notas.fiscais.xml.armazenamento'
  FILA_RETENTATIVA      = "#{FILA}-retry"
  FILA_RETENTATIVA_ERRO = "#{FILA}-error"

  to_queue FILA, arguments: { 'x-dead-letter-exchange': FILA_RETENTATIVA }

  def initialize(payload)
    @payload                      = payload
    @protocolo_entrega            = obter_protocolo
    @request_params               = @payload[:request_params].merge(protocolo_entrega: @protocolo_entrega)
    @tenant_id                    = @request_params['tenant_id']
    @substituicao_contingencia    = @request_params['substituicao_contingencia']
    @chave_acesso_contingencia    = @request_params['chave_acesso_contingencia']

    # Remove atributos que não possuem accessors dentro do model NotaFiscal. São utilizados apenas
    # para controle interno
    @request_params = @request_params.except('async', 'substituicao_contingencia')
  end

  def perform
    begin
      # Pode acontecer de alguma falha ocorrer antes de ter enviado a confirmacao
      # para o rabbitmq remover a mensagem da fila "ack!", entao a mensagem sera
      # re-emfilerada! E quando voltar a executar nao tera que processar nada
      return @protocolo_entrega if @protocolo_entrega.armazenado?
      nota_fiscal = @substituicao_contingencia ? substituir_contingencia : criar_nota_fiscal
      if nota_fiscal.errors.any?
        @protocolo_entrega.falhar!(nota_fiscal.errors.messages, ProtocoloEntrega::FALHA_VALIDACOES)
      end
    rescue StandardError => e
      @protocolo_entrega.falhar!({ internal_error: e.message }, ProtocoloEntrega::FALHA_EXCECOES)
      throw StandardError.new(e.message)
    end
    @protocolo_entrega
  end

  private

  def obter_protocolo
    ProtocoloEntrega.select(:id, :status, :created_at, :tipo_falha, :numero_tentativas)
                    .where(id: @payload[:protocolo_entrega_id]).first
  end

  def criar_nota_fiscal
    NotaFiscal.create(@request_params)
  end

  def substituir_contingencia
    nota_fiscal = localizar_nota_fiscal_contingencia_para_substituicao
    if nota_fiscal.present?
      nota_fiscal.update_attributes(@request_params)
    else
      # Caso não encontre o registro de contingência, irá retornar erro!
      # Porque não inserir o arquivo?
      #   Devido o arquivo de contingência e substituição estarem sendo processados num mesmo
      #   instante em processos diferentes em que a substituição não irá "exergar" que a
      #   contingência será inserida. Caso isto ocorra, teremos duplicidade de arquivos, e o
      #   registro de contingência nunca será substituido.
      nota_fiscal = NotaFiscal.new
      msg = I18n.t('jobs.notas_fiscais_xml_armazenamento.chave_acesso_contingencia_invalido',
                   chave: @chave_acesso_contingencia)

      # ATENÇÃO: Para mudar o nome desta chave de erro, os agentes integradores (WS, LinearMonitor),
      # deverão estar cientes, pois existem tratamentos que levam em consideração o nome.
      # Ex: SE chaveAcessoContingencia PRESENTE, ENTAO faca algo SENAO termina.
      nota_fiscal.errors.add(:chave_acesso_contingencia, msg)
    end
    nota_fiscal
  end

  def localizar_nota_fiscal_contingencia_para_substituicao
    NotaFiscal.where(tenant_id: @tenant_id)
              .where(chave_acesso: @chave_acesso_contingencia)
              .where(evento: NotaFiscal::CONTINGENCIA).first
  end
end
