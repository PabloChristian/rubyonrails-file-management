# frozen_string_literal: true

module Concerns::ObterEmpresa
  extend ActiveSupport::Concern

  private

  def obter_empresa_por_cnpj
    @empresa = current_tenant.empresas.where(cnpj: params[:cnpj]).first
  end
end
