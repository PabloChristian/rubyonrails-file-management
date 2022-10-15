# frozen_string_literal: true

class NotasFiscaisSwaggerController
  include Swagger::Blocks

  swagger_path '/notas-fiscais' do
    operation :post do
      extend SwaggerResponses::CommonsErrors
      key :summary, 'Armazenar documentos eletrÔnicos de Nota Fiscais'
      key :description, 'Guarda do xml da nota Fiscal e arquivos complementares (Inutilização, Cancelamento)'
      key :tags, ['NotaFiscal']
      parameter do
        key :body, :id
        key :name, 'body'
        key :in, :body
        key :description, 'Objeto Documento Eletrônico'
        key :required, true
        key :type, :object
        schema do
          key :'$ref', :DocumentoEletronicoInput
        end
      end
      response 200 do
        key :description, 'Id Documento Eletrônico gravado na plataforma WEB'
        schema do
          key :'$ref', :DocumentoEletronicoOutput
        end
      end
    end
  end

  swagger_path '/notas-fiscais/recuperar-conteudo' do
    operation :post do
      extend SwaggerResponses::CommonsErrors
      key :summary, 'Recupar conteúdo do XML da Nota Fiscal Eletrônica'
      key :description, 'Recuperar o conteúdo do XML do Documento Eletrônico'
      key :tags, ['NotaFiscal']
      parameter do
        key :body, :id
        key :name, 'body'
        key :in, :body
        key :description, 'Objeto com opções de  filtros'
        key :required, true
        key :type, :object
        schema do
          key :'$ref', :PesquisaPorConteudoInput
        end
      end
      response 200 do
        key :description, 'Conteudo dos Documentos Eletrônicos'
        schema do
          key :'$ref', :PesquisaPorConteudoOutput
        end
      end
    end
  end
end
