# frozen_string_literal: true
Paperclip::Attachment.default_options[:validate_media_type] = false

Paperclip.interpolates :codigo_tenant do |attachment, type|
  attachment.instance.tenant_id
end

Paperclip.interpolates :modelo do |attachment, type|
  attachment.instance.modelo
end

Paperclip.interpolates :mes_ano_emissao do |attachment, type|
  attachment.instance.mes_ano_emissao
end
