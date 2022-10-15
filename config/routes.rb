Rails.application.routes.draw do
  # For details on the DSL available within this file, see http://guides.rubyonrails.org/routing.html
  resources :apidocs, only: [:index]
  get '/docs' => redirect('/swagger/dist/index.html?url=/api-docs.json')
  resources :notas_fiscais, path: 'notas-fiscais', only: [:create, :destroy, :show] do
    post 'pesquisa', to: 'notas_fiscais#pesquisa', on: :collection
    post 'resumo-por-data', to: 'notas_fiscais#resumo_por_data', on: :collection
    get 'eventos', to: 'notas_fiscais#eventos', on: :collection
    post 'recuperar-conteudo', to: 'notas_fiscais#recuperar_conteudo', on: :collection
    put 'substituir-contingencia', to: 'notas_fiscais#substituir_contingencia', on: :collection
    post 'download-lote', to: 'downloads#create', on: :collection

    get 'protocolos-entregas/:id', to: 'protocolos_entregas#consultar', on: :collection
    delete 'protocolos-entregas', to: 'protocolos_entregas#limpar_processados', on: :collection
    post 'reenfileirar', to: 'protocolos_entregas#reenfileirar', on: :collection
  end

  resources :downloads, only: [:show] do
    post 'pesquisa', to: 'downloads#pesquisa', on: :collection
  end
end
