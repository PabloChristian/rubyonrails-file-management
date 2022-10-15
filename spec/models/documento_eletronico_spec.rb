# frozen_string_literal: true

require 'rails_helper'

NotaFiscal.skip_callback(:validation, :before, :recuperar_dados_xml_nfe)
NotaFiscal.skip_callback(:validation, :before, :setar_empresa)
NotaFiscal.skip_callback(:validation, :before, :setar_tipo_documento_eletronico)

RSpec.describe NotaFiscal, type: :model do
  it { should belong_to(:tenant) }
  it { should belong_to(:empresa) }
  it { should belong_to(:tipo_documento_eletronico) }

  it { should validate_presence_of(:tenant_id) }
  it { should validate_presence_of(:empresa_id) }
  it { should validate_presence_of(:cnpj_emitente) }
  it { should validate_presence_of(:identificacao) }
  it { should validate_presence_of(:data_emissao) }
  it { should validate_presence_of(:tipo_documento_eletronico_id) }
  it { should validate_length_of(:cnpj_cliente).is_equal_to(14) }
  it { should validate_numericality_of(:cnpj_cliente).only_integer }
  it { should validate_length_of(:cpf_cliente).is_equal_to(11) }
  it { should validate_numericality_of(:cpf_cliente).only_integer }
  it { should validate_length_of(:modelo).is_at_most(2) }
  it { should validate_length_of(:numero_cupom_fiscal).is_at_most(6) }
  it { should validate_attachment_size(:arquivo).less_than(500.kilobytes) }
end

