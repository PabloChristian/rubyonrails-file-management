class NotaFiscalMetadadosSwaggerModel
  include Swagger::Blocks

  swagger_schema :PesquisaPorConteudoInput do
    property :id do
      key :type, :integer
    end
    property :metadados do
      key :'$ref', :Metadados
    end
  end

  swagger_schema :PesquisaPorConteudoOutput do
    property :content do
      key :type, :array
      items do
        key :'$ref', :ContentPesquisaPorConteudo
      end
    end
  end

  swagger_schema :ContentPesquisaPorConteudo do
    property :id do
      key :type, :integer
    end
    property :evento do
      key :type, :integer
    end
    property :descricaoEvento do
      key :type, :string
    end
    property :nomeArquivo do
      key :type, :string
    end
    property :conteudoXml do
      key :type, :string
    end
  end

  swagger_schema :Metadados do
    property :evento do
      key :type, :integer
      key :description, '1 - Autorização; 2 - Cancelamento; 3 - Inutilização; 4 - Contingência'
    end
    property :serie do
      key :type, :integer
    end
    property :modelo do
      key :type, :string
    end
    property :protocolo do
      key :type, :string
    end
    property :codigoNota do
      key :type, :string
    end
    property :cpfCliente do
      key :type, :string
    end
    property :chaveAcesso do
      key :type, :string
    end
    property :cnpjCliente do
      key :type, :string
    end
    property :cnpjEmitente do
      key :type, :string
    end
  end
end
