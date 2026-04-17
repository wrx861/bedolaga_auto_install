# Full pipeline target

Goal: one menu action should be able to run the whole safe preparation chain:
- validate answers
- prepare layout
- fetch repos
- materialize bundles
- write metadata
- verify skeleton

Deploy-stage extension now also includes host bootstrap before live deploy:
- host bootstrap (deps/services/firewall according to host mode)
- deploy containers
- verify services live
- update/redeploy flows
