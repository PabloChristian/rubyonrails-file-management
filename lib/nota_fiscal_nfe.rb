# frozen_string_literal: true

module NotaFiscalNfe
  module InstanceMethods
    private

    # Codigos de evento de acordo com o manual sefaz
    TP_EVENTO_CANCELAMENTO = %w[110111 110112].freeze
    CODIGO_CONTINGENCIA = '9'

    def recuperar_dados_xml_nfe
      case evento
      when NotaFiscal::AUTORIZACAO
        recuperar_dados_xml_nfe_autorizacao
      when NotaFiscal::CONTINGENCIA
        recuperar_dados_xml_nfe_contigencia
      when NotaFiscal::CANCELAMENTO
        recuperar_dados_xml_nfe_cancelamento
      when NotaFiscal::INUTILIZACAO
        recuperar_dados_xml_nfe_inutilizacao
      end
    end

    def recuperar_dados_xml_nfe_autorizacao
      @doc = Nokogiri::XML(conteudo_xml)

      recuperar_dados_comuns_autorizacao
      chave = nfe_value('//xmlns:infProt', 'chNFe')
      self.chave_acesso = chave
      self.protocolo    = nfe_value('//xmlns:infProt', 'nProt')

      # valor 1 na posicao 34 indica autorizacao e 9 contigência
      # Arquivos de Autorizações "normais" sempre estarão com valor igual a 1. Já os arquivos
      # que substitui a contigência virá com valor igual a 9 e também terá número de protocolo.
      self.xml_autorizacao = (chave[34] == '1' || (chave[34] == CODIGO_CONTINGENCIA && protocolo.present?)) if chave.present?
    end

    def recuperar_dados_xml_nfe_contigencia
      xml = conteudo_xml.gsub('<NFe>', '<NFe xmlns="http://www.portalfiscal.inf.br/nfe">')
      @doc = Nokogiri::XML(xml)

      recuperar_dados_comuns_autorizacao
      chave = nfe_attribute_value('infNFe', 'Id').to_s.downcase.gsub('nfe', '')
      self.chave_acesso     = chave
      self.protocolo        = nil
      # valor 9 na posicao 34 indica contingência
      self.xml_contingencia = chave[34] == CODIGO_CONTINGENCIA if chave.present?
    end

    def recuperar_dados_comuns_autorizacao
      self.cnpj_emitente =            nfe_value('//xmlns:emit', 'CNPJ')
      self.data_emissao =             nfe_value('//xmlns:ide', 'dhEmi')
      self.modelo =                   nfe_value('//xmlns:ide', 'mod')
      self.codigo_nota =              nfe_value('//xmlns:ide', 'cNF')
      self.serie =                    nfe_value('//xmlns:ide', 'serie')
      self.cnpj_cliente =             nfe_value('//xmlns:dest', 'CNPJ')
      self.cpf_cliente =              nfe_value('//xmlns:dest', 'CPF')
    end

    def recuperar_dados_xml_nfe_cancelamento
      @doc = Nokogiri::XML(conteudo_xml)
      tp_evento =                     nfe_value('//xmlns:infEvento', 'tpEvento')
      self.xml_cancelamento =         TP_EVENTO_CANCELAMENTO.include?(tp_evento)
      self.cnpj_emitente =            nfe_value('//xmlns:infEvento', 'CNPJ')
      self.chave_acesso =             nfe_value('//xmlns:infEvento', 'chNFe')
      self.data_emissao =             nfe_value('//xmlns:infEvento', 'dhEvento')
      self.protocolo =                nfe_value('//xmlns:infEvento', 'nProt')
      recuperar_informacoes_documento_referenciado
    end

    def recuperar_informacoes_documento_referenciado
      # Recupera documento referenciado pela chave de acesso
      # Segundo informacao passada, pode acontecer do documento que esta sendo cancelado
      # nao ter subido, entao informacoes como: modelo, codigo_nota e serie serao recuperados
      # das posicoes da propria chave de acesso
      return if chave_acesso.nil?
      self.documento_referenciado = NotaFiscal.select('id, metadados, cancelado')
                                              .where(tenant_id: tenant_id)
                                              .where(chave_acesso: chave_acesso).take
      if documento_referenciado
        self.modelo =                   documento_referenciado.metadados['modelo']
        self.cnpj_cliente =             documento_referenciado.metadados['cnpj_cliente']
        self.cpf_cliente =              documento_referenciado.metadados['cpf_cliente']
        self.codigo_nota =              documento_referenciado.metadados['codigo_nota']
        self.serie =                    documento_referenciado.metadados['serie']
      else
        self.modelo =                   chave_acesso[20, 2]
        self.codigo_nota =              chave_acesso[35, 8]
        self.serie =                    chave_acesso[22, 3]
      end
    end

    def recuperar_dados_xml_nfe_inutilizacao
      @doc = Nokogiri::XML(conteudo_xml)
      self.cnpj_emitente =            nfe_value('//xmlns:infInut', 'CNPJ')
      self.data_emissao =             nfe_value('//xmlns:infInut', 'dhRecbto')
      self.modelo =                   nfe_value('//xmlns:infInut', 'mod')
      self.protocolo =                nfe_value('//xmlns:infInut', 'nProt')
      self.serie =                    nfe_value('//xmlns:infInut', 'serie')
      # Se encontrou a tag dentro de infInut significa ser um xml de Inutilizacao
      self.xml_inutilizacao =         protocolo.present?
    end

    def nfe_value(xpath, name)
      @doc.xpath(xpath).children.each do |node|
        return node.text if node.name == name
      end
      nil
    rescue StandardError => e
      errors.add(:base, e.message)
    ensure
      nil
    end

    def nfe_attribute_value(element_name, attribute_name)
      @doc.css(element_name).attribute(attribute_name).value.to_s
    rescue StandardError => e
      errors.add(:base, e.message)
    ensure
      nil
    end

    def setar_metadados_pesquisa
      self.metadados = {
        cnpj_emitente: cnpj_emitente,
        chave_acesso: chave_acesso,
        modelo: modelo,
        cnpj_cliente: cnpj_cliente,
        cpf_cliente: cpf_cliente,
        codigo_nota: codigo_nota,
        protocolo: protocolo,
        evento: evento,
        serie: serie.to_i
      }
    end

    # Validacoes
    def empresa_emitente_pertence_ao_tenant
      self.empresa_id = Empresa.select(:id).where(tenant_id: tenant_id, cnpj: cnpj_emitente).first&.id
      return if empresa_id
      msg = I18n.t('activerecord.errors.documento_eletronico.emitente_invalido', cnpj: cnpj_emitente)
      errors.add(:empresa_id, msg)
    end

    # Validacao para garantir que o xml que esta chegando pertence a loja que emitiu, isto evita que
    # o token da loja "A" seja utilizado na loja "B". Esta regra se aplica bem no cenario de NFCe.
    # Rever a regra quando for subir outros tipos de documentos que nao for transmitido pelo PDV
    def empresa_emitente_e_empresa_token_acesso
      return if cnpj_empresa_token == cnpj_emitente
      msg = I18n.t('controllers.errors.cnpj_token_diferente', cnpj: cnpj_emitente, cnpj_token: cnpj_empresa_token)
      errors.add(:empresa_id, msg)
    end

    # Verificação de duplicidade é executada apenas para Autorização e Contigência, pois:
    #   Cancelamento: Já vai existir o documento autorizado com a chave, porém será validado o
    #                 número de protocolo
    #   Inutilização: Não tem chave de acesso
    def chave_acesso_unica
      return if [NotaFiscal::CANCELAMENTO, NotaFiscal::INUTILIZACAO].include?(evento)
      return if chave_acesso_contingencia
      return if chave_acesso.nil?
      documento = NotaFiscal.select(:id, :evento)
                            .where(tenant_id: tenant_id, chave_acesso: chave_acesso)
                            .where('evento in (?)', [NotaFiscal::AUTORIZACAO, NotaFiscal::CONTINGENCIA])
                            .take
      return unless documento

      # IMPORTANTE: Quando o evento da requisição for 1 - Autorização e já existir um documento de
      # contingência para aquela chave de acesso, não poderá retornar o erro id_duplicado. Pois o
      # WS Linear, interpreta que o documento já esta gravado e deixa de enviá-lo.
      if evento == NotaFiscal::AUTORIZACAO && documento.evento == NotaFiscal::CONTINGENCIA
        errors.add(:chave_acesso,
                   I18n.t('activerecord.errors.documento_eletronico.contigencia_existente'))
      else
        errors.add(:id_duplicado, documento.id)
      end
      errors.add(:chave_acesso,
                 I18n.t('activerecord.errors.documento_eletronico.chave_acesso_duplicada'))
    end

    def documento_cancelamento_ja_cadastrado_para_o_referenciado
      return if evento != NotaFiscal::CANCELAMENTO || documento_referenciado.nil?
      return if chave_acesso.nil?
      documento = NotaFiscal.select(:id)
                            .where(tenant_id: tenant_id, chave_acesso: chave_acesso)
                            .where('evento = ?', NotaFiscal::CANCELAMENTO).take
      return unless documento
      errors.add(:id_duplicado, documento.id)
      errors.add(:chave_acesso,
                 I18n.t('activerecord.errors.documento_eletronico.duplicidade_cancelamento'))
    end

    def evento_compativel_com_o_documento
      if evento == NotaFiscal::CANCELAMENTO && !xml_cancelamento ||
         evento == NotaFiscal::INUTILIZACAO && !xml_inutilizacao ||
         evento == NotaFiscal::CONTINGENCIA && !xml_contingencia ||
         evento == NotaFiscal::AUTORIZACAO && !xml_autorizacao
        errors.add(:evento, I18n.t('activerecord.errors.documento_eletronico.evento_incompativel'))
      end
    end

    def protocolo_unico
      # - Só verifca o número de protocolo quando não tiver erros na chave de acesso. Forma de evitar
      #   mais um select no banco de dados
      # - Protocolo nulo não faz pesquisa, pois, documentos de contigência não possuem protocolo
      return if errors[:chave_acesso].present? || protocolo.nil?
      documento = NotaFiscal.select(:id).where(tenant_id: tenant_id, protocolo: protocolo).take
      return unless documento
      errors.add(:id_duplicado, documento.id)
      errors.add(:protocolo,
                 I18n.t('activerecord.errors.documento_eletronico.protocolo_duplicado'))
    end

    def verificar_substituicao_contigencia
      return unless chave_acesso_contingencia

      msg = I18n.t('activerecord.errors.documento_eletronico.evento_substituicao_nao_permitido')
      errors.add(:evento, msg) if evento != NotaFiscal::AUTORIZACAO

      msg = I18n.t('activerecord.errors.documento_eletronico.chave_acesso_divergente')
      if chave_acesso != metadados_was['chave_acesso'] || # Chave de acesso do arquivo diferente da chave de acesso do documento que esta sendo atualizado
         chave_acesso_contingencia != chave_acesso        # Chave de acesso do arquivo diferente da chave de acesso passada como parâmetro na requisição
        errors.add(:chave_acesso_contingencia, msg)
      end

      if chave_acesso_contingencia.present? && chave_acesso.present? &&
         chave_acesso[34] != CODIGO_CONTINGENCIA
        msg = I18n.t('activerecord.errors.documento_eletronico.xml_substituicao_invalido')
        errors.add(:chave_acesso_contingencia, msg)
      end
    end
  end

  def self.included(base)
    base.send :include, InstanceMethods
    base.before_validation :recuperar_dados_xml_nfe
    base.before_save :setar_metadados_pesquisa
    base.validate :empresa_emitente_pertence_ao_tenant,
                  :empresa_emitente_e_empresa_token_acesso,
                  :chave_acesso_unica,
                  :documento_cancelamento_ja_cadastrado_para_o_referenciado,
                  :evento_compativel_com_o_documento,
                  :protocolo_unico,
                  :verificar_substituicao_contigencia
  end
end
