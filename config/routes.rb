Debt::Application.routes.draw do
  controller :main do
    # get "show"
    get "edit"
    post "update"
  end
  root to: "main#show"
end
