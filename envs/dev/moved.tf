# S06 : renommage du module de supervision. Le bloc reste dans le code : il documente
# l'historique et permet a un collegue au state en retard de rattraper le deplacement.
# L'adresse complete d'un module est module.<nom> (tout son contenu suit).
moved {
  from = module.monitoring
  to   = module.monitoring_dev
}
