# frozen_string_literal: true

require 'rails_helper'
# require 'rack/test'
Venda.skip_callback(:validation, :before, :setar_empresa)
Venda.skip_callback(:validation, :before, :setar_cliente)
Venda.skip_callback(:validation, :before, :setar_turno)
Venda.skip_callback(:create, :after, :gerar_numeros_sorte)
Venda.skip_callback(:create, :before, :calcular_quantidade_numeros_sorte)

RSpec.describe Venda do
  attributes = {
    tenant_id: 1,
    empresa_id: 1,
    parceiro_id: 1,
    data_venda: DateTime.now,
    hora_venda: Time.now,
    numero_cupom: 1,
    quantidade_itens: 10,
    quantidade_itens_com_desconto: 10,
    quantidade_itens_com_desconto_exclusivo: 5,
    total_bruto: 100,
    total_desconto: 5,
    total_desconto_exclusivo: 1,
    total_desconto_nao_exclusivo: 3,
    total_outros_descontos: 10,
    total_acrescimos: 10,
    total_liquido: 5,
    quantidade_numeros_sorte: 2,
    turno: 1,
    payload: 'teste',
    cpf_cliente: '09926301694',
    numero_caixa: 111,
  }
  subject { described_class.new(attributes) }
  describe 'validations' do
    describe 'tenant_id' do
      it 'deve estar presente' do
        subject.tenant_id = nil
        expect(subject).to_not be_valid
      end
    end
    describe 'parceiro_id' do
      it 'deve estar presente' do
        subject.parceiro_id = nil
        expect(subject).to_not be_valid
      end
    end
    describe 'registro_venda_id' do
      it 'deve estar presente' do
        subject.empresa_id = nil
        expect(subject).to_not be_valid
      end
    end
  end
end