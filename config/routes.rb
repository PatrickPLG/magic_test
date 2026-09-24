MagicTest::Engine.routes.draw do
  get "recorder.js", to: "recorder#script"
  get "config", to: "recorder#bootstrap"
  get "state", to: "recorder#state"
  post "events", to: "recorder#events"
  post "commands", to: "recorder#commands"
end
