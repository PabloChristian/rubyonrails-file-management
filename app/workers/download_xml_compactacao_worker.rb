# frozen_string_literal: true

class DownloadXmlCompactacaoWorker < WorkerBase
  include Sneakers::Worker
  options = {
    durable: true,
    ack: true,
    retry_routing_key: DownloadXmlCompactacaoJob::FILA,
    timeout_job_after: 0,
    threads: 3,
    prefetch: 3
  }
  from_queue DownloadXmlCompactacaoJob::FILA, options

  def work(payload)
    job = DownloadXmlCompactacaoJob.new(decode_data(payload))
    tarefa = job.perform
    return ack! if tarefa.concluida?
    return requeue!
  rescue StandardError => e
    logger.error e.message
    return requeue!
  end
end
