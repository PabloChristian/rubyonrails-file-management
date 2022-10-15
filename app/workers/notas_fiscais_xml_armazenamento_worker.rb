# frozen_string_literal: true

class NotasFiscaisXmlArmazenamentoWorker < WorkerBase
  include Sneakers::Worker

  options = {
    durable: true,
    ack: true,
    retry_routing_key: NotasFiscaisXmlArmazenamentoJob::FILA,
    timeout_job_after: 0,
    threads: 10,
    prefetch: 10,
    retry_timeout: 60 * 1000, # 60 segundos
    retry_exchange: NotasFiscaisXmlArmazenamentoJob::FILA_RETENTATIVA,
    retry_error_exchange: NotasFiscaisXmlArmazenamentoJob::FILA_RETENTATIVA_ERRO
  }

  from_queue NotasFiscaisXmlArmazenamentoJob::FILA, options.merge(
    arguments: { 'x-dead-letter-exchange': NotasFiscaisXmlArmazenamentoJob::FILA_RETENTATIVA }
  )

  def work(payload)
    job = NotasFiscaisXmlArmazenamentoJob.new(decode_data(payload))
    protocolo = job.perform
    return ack! if protocolo.armazenado? || protocolo.falha_validacoes?
    return reject!
  rescue StandardError => e
    logger.error "Errors: #{e.message} =-> Payload: #{payload}"
    return reject!
  end
end
