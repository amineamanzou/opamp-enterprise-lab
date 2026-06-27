---
series: opamp-enterprise-adoption
part: 4
language: fr
status: draft
evidence_review: complete
contradictory_review: complete
---

# OpAMP et l'adoption entreprise, partie 4: sortie, secrets et panne

Un plan de controle ne se juge pas seulement quand tout fonctionne. Il se juge quand on veut le quitter, quand un secret est faux, quand le serveur tombe et quand l'interface garde des lignes obsoletes.

Cette partie est la plus operationnelle de la serie. Le laboratoire final a teste une sortie vers le chemin OpAMP Go, un inventaire de secrets, une panne du plan de controle et la destruction du lab. Les resultats sont utiles parce qu'ils ne racontent pas une demo parfaite. Ils exposent les endroits ou une architecture entreprise doit encore etre durcie.

Les captures devraient etre utilisees largement ici:

- `assets/screenshots/kibana-opamp-overview.png` pour montrer les compteurs OpAMP, logs synthetiques et evenements de lifecycle;
- `assets/screenshots/kibana-opamp-agent-lifecycle.png` pour montrer les changements de configuration, sante, connexion et deconnexion;
- `assets/screenshots/kibana-opamp-volumetry-capacity.png` pour montrer les metriques serveur, host, Kubernetes et collecteur;
- `assets/screenshots/kibana-fleet-agents-table.png` pour montrer les lignes Fleet `otelcol-contrib` restees offline.

Les fichiers originaux de preuve vivent dans le run `20260619T223502Z-exit-drill-secrets-outage`; les chemins ci-dessus correspondent a l'emplacement editorial attendu pour les captures sanitisees.

## Sortir de Fleet OTel-only

Le chemin Fleet vers OpAMP Go n'a pas ete remesure de bout en bout pendant le drill final, car le collecteur Fleet etait deja arrete au debut du run. C'est important: il ne faut pas pretendre avoir mesure un downtime Fleet-vers-OpAMP dans cette execution.

Ce que le lab peut dire est plus limite, mais utile. Le run precedent avait prouve qu'un collecteur upstream `otelcol-contrib` pouvait etre visible dans Fleet et envoyer des logs. Le drill final a observe que Fleet conservait trois lignes `otelcol-contrib` offline, avec une activite datant de quelques heures. La sortie laisse donc une trace dans l'ancien plan de controle.

Techniquement, remplacer l'endpoint OpAMP, l'auth header et le service collecteur est faisable. Operationnellement, la difficulte se deplace vers l'automatisation: conserver une identite stable, eviter les doublons, reprendre ou reconstruire les dashboards, gerer les credentials et nettoyer l'ancien inventaire.

La conclusion est donc "partiellement immediate", pas "sortie prouvee sans interruption". Le binaire Collector et le chemin OTLP sont portables. Le lifecycle, l'identite et la proprete du plan de controle restent a gerer.

## Sortir de Bindplane BDOT

La sortie Bindplane vers OpAMP Go a ete executee mecaniquement. Le service BDOT `observiq-otel-collector.service` a ete arrete, puis le service superviseur OpAMP `opampsupervisor-logs.service` a ete demarre. A l'echelle systemd, le service de remplacement est devenu actif en moins d'une seconde.

Mais la mesure de continuite du chemin de donnees n'etait pas possible depuis BDOT, car la configuration BDOT active etait une configuration minimale `nop`. Il n'y avait donc pas de baseline Elastic BDOT a preserver. Le collecteur de remplacement a bien exporte ensuite des logs et metriques vers Elastic, mais cela prouve une reprise du chemin de donnees, pas une continuite stricte depuis un pipeline Bindplane equivalent.

Bindplane a conserve l'ancien agent `opamp-poc-agent` comme `Disconnected`, avec type `BDOT 1.x (Stable)` et version `v1.101.2`. Cette preuve est documentee dans le resume navigateur et les resultats du drill: elle montre que la sortie ne se termine pas au moment ou le nouveau service demarre. Il reste un sujet de nettoyage, d'audit et de reconciliation dans l'ancien plan de controle.

Le travail de sortie comprend aussi la reconstruction de la configuration. Le modele Bindplane source/destination doit etre traduit en YAML OTel portable si l'organisation veut garder une reversibilite propre. Sans export ou convention claire, la sortie devient un exercice manuel.

## Les lignes obsoletes sont un signal de maturite

Les lignes obsoletes peuvent sembler anecdotiques dans un lab. A l'echelle d'un parc, elles deviennent un probleme d'exploitation.

Fleet a conserve trois lignes offline apres le run OTel-only. Bindplane a conserve la ligne BDOT deconnectee. Le serveur OpAMP Go a conserve un inventaire historique volumineux issu de tests de scale: le recapitulatif mentionne 10 022 agents de tests anterieurs encore presents dans l'inventaire.

Ce n'est pas un sujet esthetique. Un inventaire sale fausse les taux de sante, les alertes, les rapports de conformite et les decisions de rollout. Une plateforme entreprise a besoin d'une politique explicite: TTL des agents, etats terminalement retires, suppression auditee, distinction entre "deconnecte temporairement" et "sorti du parc".

OpAMP ne resout pas cette politique a lui seul. Le produit au-dessus doit la definir.

## Secrets: le test qui change le niveau de risque

Le catalogue de secrets du lab identifie plusieurs categories: `OPAMP_AUTH_TOKEN`, `ELASTIC_API_KEY`, auth Fleet OpAMP, secret key Bindplane, API key Bindplane, identite SOPS age et objets Kubernetes Secret.

Le probleme commun n'est pas la creation initiale. Le vrai sujet est la rotation sans coupure, la revocation, la segmentation du blast radius et l'auditabilite.

Le test destructif le plus important concerne `OPAMP_AUTH_TOKEN`. Le drill a remplace le token de l'agent host par une valeur volontairement invalide, puis a redemarre `opampsupervisor-logs.service`. Resultat: le superviseur est reste actif, le collecteur local est redevenu sain rapidement, et l'inventaire OpAMP Go s'est rafraichi. Le serveur acceptait donc la connexion malgre le token invalide.

La conclusion est critique: dans l'implementation Go du lab, `OPAMP_AUTH_TOKEN` etait une ceremonie de configuration, pas une frontiere d'acces effective. Avant production, il faut une validation bearer cote serveur, des tokens segmentes par cohorte ou environnement, une periode de chevauchement pour rotation, une revocation testable et des evenements d'echec auth auditables.

Fleet et Bindplane n'ont pas subi de rotation destructive pendant ce drill. Leur rotation reste a documenter via UI/API produit, sans modifier des credentials de compte dans un lab public.

## Panne du plan de controle: le chemin de donnees a tenu

Le test le plus favorable au chemin OpAMP ouvert est la panne du serveur OpAMP Go. Le service `opamp-poc-server.service` a ete arrete tandis que `opampsupervisor-logs.service` continuait a tourner.

Le resultat attendu d'une bonne architecture est simple: si le collecteur possede deja une configuration locale valide, le chemin de donnees doit continuer meme si le plan de controle est indisponible. Le lab l'a confirme pour ce scenario. Elastic a recu 1 898 evenements host/supervisor dans une fenetre de deux minutes pendant l'indisponibilite. Les logs host, metriques host, logs collecteur et metriques collecteur ont continue a arriver.

Apres redemarrage du serveur a `2026-06-19T22:40:04Z`, l'horodatage d'inventaire host-agent s'est rafraichi vers `2026-06-19T22:40:29Z`, soit environ 25 secondes. Cette valeur est un resultat de lab, pas une garantie generale.

La capture `assets/screenshots/kibana-opamp-volumetry-capacity.png` devrait porter cette section: elle montre pourquoi il faut observer le plan de controle lui-meme, pas seulement les logs applicatifs.

Il reste une reserve forte. Pendant que l'inventaire se rafraichissait, les endpoints `/v1/opamp/connections` et `connected_agents` rapportaient zero connexion active. C'est une lacune d'observabilite du serveur custom. En production, un plan de controle qui ne sait pas compter correctement ses connexions actives ne peut pas piloter sereinement la montee en charge.

## Destruction du lab

Le dernier acte du run a ete la destruction de l'infrastructure. Terraform a supprime quatre serveurs Hetzner, un firewall et une cle SSH, soit six ressources. Les verifications post-destroy ont montre un state vide et zero serveur ou firewall restant avec le label du projet.

Cette etape compte editorialement. Elle ferme le perimetre public: les preuves restantes sont les documents du repository, les captures sanitisees et les historiques SaaS encore visibles cote Elastic, Fleet ou Bindplane. Elle evite aussi de laisser des ressources, secrets ou endpoints trainer apres une etude.

Le verdict de cette partie est net: OpAMP peut preserver le chemin de donnees pendant une panne de plan de controle si le collecteur local a deja une configuration valide. Mais la sortie, les secrets, les lignes obsoletes et l'auditabilite restent des sujets produit. Pour une grande entreprise, ce sont des exigences de base, pas des finitions.
