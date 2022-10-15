# frozen_string_literal: true

class DownloadXmlColetaWorker < WorkerBase
  include Sneakers::Worker

  options = {
    durable: true,
    ack: true,
    retry_routing_key: DownloadXmlColetaJob::FILA,
    timeout_job_after: 0,
    threads: 4,
    prefetch: 4
  }
  from_queue DownloadXmlColetaJob::FILA, options

  def work(payload)
    job = DownloadXmlColetaJob.new(decode_data(payload))
    tarefa = job.perform
    return ack! if tarefa.concluida?
    return requeue!
  rescue StandardError => e
    logger.error e.message
    return requeue!
  end
end
