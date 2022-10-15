# frozen_string_literal: true

module FiltroPorPeriodoScope
  HOJE = 1
  ONTEM = 5
  SEMANA_ATUAL = 10
  SEMANA_PASSADA = 15
  MES_ATUAL = 20
  MES_PASSADO = 25

  TIPOS_VALIDOS = [HOJE, ONTEM, SEMANA_ATUAL, SEMANA_PASSADA, MES_ATUAL, MES_PASSADO].freeze

  def self.included(base)
    base.scope :por_periodo, (lambda do |campo, params, nome_campo_bd = nil, campo_date_time = false|
      data_inicio = params["#{campo}_inicial"] || params["#{campo}_inicial".to_sym]
      data_final = params["#{campo}_final"]    || params["#{campo}_final".to_sym]
      if data_final.present? && data_final.present?
        nome_campo_bd = campo if nome_campo_bd.nil?
        if !campo_date_time
          where("#{nome_campo_bd} between ? and ?", data_inicio, data_final)
        else
          where("#{nome_campo_bd} between ? and ?", "#{data_inicio} 00:00:00", "#{data_final} 23:59:59")
        end
      end
    end)

    base.scope :por_tipo_periodo, (lambda do |campo, params|
      if params['tipo_periodo'].present?
        datas = datas(params['tipo_periodo'])
        return where("#{campo} between ? and ?", datas.first, datas.last)
      end
    end)

    base.scope :datas, (lambda do |tipo_periodo|
      case tipo_periodo
      when HOJE
        [Time.zone.now.to_date, Time.zone.now.to_date]
      when ONTEM
        [(Time.zone.now - 1.day).to_date, (Time.zone.now - 1.day).to_date]
      when SEMANA_ATUAL
        [Time.zone.now.beginning_of_week.to_date, Time.zone.now.end_of_week.to_date]
      when SEMANA_PASSADA
        [
          (Time.zone.now - 1.week).beginning_of_week.to_date,
          (Time.zone.now - 1.week).end_of_week.to_date.to_date
        ]
      when MES_ATUAL
        [Time.zone.now.beginning_of_month.to_date, Time.zone.now.end_of_month.to_date]
      when MES_PASSADO
        [
          (Time.zone.now - 1.month).beginning_of_month.to_date,
          (Time.zone.now - 1.month).end_of_month.to_date
        ]
      end
    end)
  end
end
