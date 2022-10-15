# frozen_string_literal: true

class ApplicationController < ActionController::API
  include AbstractController::Helpers
  include Response

  before_action :decode_authorization_token,
                except: [
                  :reenfileirar
                ]

  helper_method :current_tenant
  helper_method :current_partner_id
  helper_method :current_user_id
  helper_method :current_cnpj_empresa
  helper_method :tenant_linear?

  private

  def current_tenant
    @tenant
  end

  def current_partner_id
    @partner_id
  end

  def current_user_id
    @user_id
  end

  def current_cnpj_empresa
    @cnpj_empresa
  end

  def tenant_linear?
    @tenant_linear || false
  end

  # def current_user
  #   @user
  # end

  def decode_authorization_token
    authorization = request.headers['Authorization']
    if authorization.nil?
      render json: { message: I18n.t('controllers.errors.token_nao_informado') }, status: 400
    else
      token = authorization.gsub('Bearer', '').strip
      decoded_token = JWT.decode token, nil, false
      @decoded_token = JSON.parse(decoded_token.first['_usr'])
      @cnpj_empresa = @decoded_token['cnpj'] unless @decoded_token.nil?
      load_tenant
      load_user
    end
  end

  def load_tenant
    unless @decoded_token.nil?
      @tenant = Tenant.where(id: @decoded_token['tenant']).first
      @tenant_linear = @decoded_token['isLinear']
    end
    message = I18n.t('controllers.errors.tenant_nao_localizado')
    render json: { message: message }, status: 400 if @tenant.nil?
  end

  def load_user
    unless @decoded_token.nil?
      # @user = Usuario.where(id: @decoded_token['id']).first
      @user_id = @decoded_token['id']
      @partner_id = @decoded_token['partner']
    end
    message = I18n.t('controllers.errors.usuario_nao_localizado')
    render json: { message: message }, status: 400 if @user_id.nil?
  end
end
