# frozen_string_literal: true

class DownloadXmlLimpezaWorker < WorkerBase
  include Sneakers::Worker

  options = {
    durable: true,
    ack: true,
    retry_routing_key: DownloadXmlLimpezaJob::FILA,
    timeout_job_after: 0,
    threads: 1,
    prefetch: 1
  }
  from_queue DownloadXmlLimpezaJob::FILA, options

  def work(payload)
    job = DownloadXmlLimpezaJob.new(decode_data(payload))
    tarefa = job.perform
    return ack! if tarefa.concluida?
    return requeue!
  rescue StandardError => e
    logger.error e.message
    return requeue!
  end
end
