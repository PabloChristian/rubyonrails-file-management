# frozen_string_literal: true

class DownloadXmlPreparacaoWorker < WorkerBase
  include Sneakers::Worker

  options = {
    durable: true,
    ack: true,
    retry_routing_key: DownloadXmlPreparacaoJob::FILA,
    timeout_job_after: 0,
    threads: 2,
    prefetch: 2
  }
  from_queue DownloadXmlPreparacaoJob::FILA, options

  def work(payload)
    job = DownloadXmlPreparacaoJob.new(decode_data(payload))
    tarefa = job.perform
    return ack! if tarefa.concluida?
    return requeue!
  rescue StandardError => e
    logger.error e.message
    return requeue!
  end
end
