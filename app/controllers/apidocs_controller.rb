# frozen_string_literal: true

class ApidocsController < ActionController::Base
  include Swagger::Blocks

  swagger_root do
    key :swagger, '2.0'
    info do
      key :version, '1.0.0'
      key :title, 'Documentos Eletrônicos'
      key :description, 'API REST de Guarda de Documentos Eletrônicos da solução SG Web, responsável
                        pelos processos de guarda, consulta e download de XML`s (NFe, NFCe e etc...)'
      contact do
        key :name, 'Team WEB'
      end
    end
    tag do
      key :name, 'NotaFiscal'
    end
    key :host, 'http://ec2-35-174-43-96.compute-1.amazonaws.com:32304'
    key :basePath, '/documentos-eletronicos/docs/'
    key :consumes, ['application/json']
    key :produces, ['application/json']
  end

  # A list of all classes that have swagger_* declarations.
  classes = [self]
  Dir.glob('swagger_artifacts/**/*.rb').each do |file|
    file_name = file[file.rindex('/') + 1, file.length]
    classes << file_name.gsub('.rb', '').camelize.constantize
  end
  SWAGGERED_CLASSES = classes.freeze

  def index
    swagger_data = Swagger::Blocks.build_root_json(SWAGGERED_CLASSES)
    File.open('public/api-docs.json', 'w') { |file| file.write(swagger_data.to_json) }
    redirect_to '/swagger/dist/index.html?url=/api-docs.json'
  end
end
