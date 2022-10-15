class DocumentoEletronicoSwaggerModel
  include Swagger::Blocks

  swagger_schema :DocumentoEletronicoInput do
    key :required, [:evento, :nomeArquivo, :conteudoXml]
    property :evento do
      key :type, :integer
      key :description, '1 - Autorização; 2 - Cancelamento; 3 - Inutilização; 4 - Contingência'
    end
    property :nomeArquivo do
      key :type, :string
    end
    property :conteudoXml do
      key :type, :string
    end
  end

  swagger_schema :DocumentoEletronicoOutput do
    property :content do
      key :'$ref', :Content
    end
  end

  swagger_schema :Content do
    property :id do
      key :type, :integer
    end
  end
end
