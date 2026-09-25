MagicTest::Engine.routes.draw do
  get "recorder.js", to: "recorder#script"
  get "config", to: "recorder#bootstrap"
  get "state", to: "recorder#state"
  post "events", to: "recorder#events"
  post "commands", to: "recorder#commands"

  # The new-test wizard (1.1)
  get "new", to: "wizard#page"
  get "wizard.js", to: "wizard#script"
  get "wizard/catalogue", to: "wizard#catalogue"
  get "wizard/state", to: "wizard#state"
  post "wizard/:name", to: "wizard#command", constraints: {name: /preview|preflight|start|cancel/}
end
