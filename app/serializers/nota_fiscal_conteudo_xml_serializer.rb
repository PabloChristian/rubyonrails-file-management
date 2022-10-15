# frozen_string_literal: true

class NotaFiscalConteudoXmlSerializer < BaseSerializer
  attributes :id, :nome_arquivo, :evento, :descricao_evento, :conteudo_xml

  def descricao_evento
    return '' unless object.evento
    I18n.t('activerecord.attributes.eventos')[object.evento]
  end

  def nome_arquivo
    object.arquivo_file_name
  end

  def conteudo_xml
    uri = URI(object.arquivo.url)
    res = Net::HTTP.get_response(uri)
    res.body.force_encoding('utf-8')
  end
end
