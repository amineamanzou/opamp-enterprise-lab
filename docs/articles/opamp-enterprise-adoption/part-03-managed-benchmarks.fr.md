---
series: opamp-enterprise-adoption
part: 3
language: fr
status: draft
evidence_review: complete
contradictory_review: complete
---

# OpAMP et l'adoption entreprise, partie 3: ce que montrent les plans de controle manages

Le chemin ouvert est important, mais une evaluation entreprise doit aussi regarder les plans de controle manages. Non pas pour declarer un vainqueur global, mais pour mesurer ce qu'un produit absorbe deja: onboarding, inventaire, statut, interface, workflows et support jour 2.

Le laboratoire compare deux benchmarks principaux: Elastic Fleet en mode OpenTelemetry only, et Bindplane avec BDOT. Les deux chemins sont utiles, mais ils ne repondent pas exactement a la meme question.

Fleet OTel-only montre ce qu'un produit Elastic sait voir et suivre lorsqu'un collecteur OpenTelemetry se connecte a Fleet via OpAMP, sans installer Elastic Agent. Bindplane montre une experience produit plus orientee construction et gestion de pipelines Collector, avec BDOT comme distribution geree.

Dans les deux cas, il faut separer trois sujets: le chemin de donnees, le plan de controle et la reversibilite.

## Fleet OTel-only: visibilite utile, lifecycle encore externe

Le run Fleet OTel-only a connecte un collecteur upstream `otelcol-contrib` 0.151.0. Le resultat est positif sur la visibilite: le collecteur apparait sain, les logs sont visibles dans le backend, le statut passe offline puis healthy lors d'un arret/redemarrage, et la configuration effective peut etre inspectee.

Cette partie est importante. Elle montre qu'il existe un chemin OpenTelemetry sans Elastic Agent dans le lab. Pour une equipe qui utilise deja Elastic comme backend, c'est une piste interessante pour observer certains collecteurs avec une interface connue.

Mais le lab a aussi montre les limites. La configuration distante editable n'a pas ete trouvee pour ce flux. Les operations de redemarrage, stop/start, validation de mauvaise configuration et cleanup restent externes, via systemd, SSH ou automation. Une mauvaise configuration est attrapee par `otelcol validate` ou par le service local, pas par une policy Fleet poussee dans ce scenario.

Le redemarrage a aussi expose un sujet d'identite: sans `instance_uid` stable, des lignes obsoletes peuvent apparaitre. Une fois l'identite stabilisee, les redemarrages deviennent plus propres, mais le risque est exactement celui d'un grand parc: une petite difference d'identite devient vite du bruit d'inventaire.

Le palier de montee en charge a ete bloque. Le run avec dix collecteurs a d'abord rencontre des conflits de configuration et de telemetrie, puis un `401` lie a la reutilisation d'un credential genere. C'est une information utile, pas un echec anecdotique. Elle indique qu'un onboarding multi-collecteur demande un workflow par collecteur ou une API d'automatisation plus claire, avec gestion des secrets et redaction.

Conclusion Fleet OTel-only: tres utile comme benchmark de visibilite, pas prouve comme plan de controle complet pour un parc OpenTelemetry upstream dans ce lab.

La capture `assets/screenshots/kibana-fleet-agents-table.png` montre le cout des lignes obsoletes apres sortie ou redemarrage. La valeur immediate de l'UI Fleet est decrite depuis les notes navigateur et les resultats CSV conserves.

## Bindplane: meilleur workflow produit, couplage a assumer

Le premier passage Bindplane a connecte un agent BDOT 1.101.2 sur une VM Linux. L'onboarding est plus produit: l'interface genere une commande, l'agent apparait dans la liste, le statut Connected/Disconnected est visible, et les details incluent version, OS, identifiant agent, adresse distante, labels, fleet et configuration.

Pour une equipe plateforme, cette experience compte. Elle reduit le travail de construction d'interface, donne un modele de source/destination et rapproche l'operateur d'un vrai workflow jour 2. La creation d'une source File a ete testee et sauvegardee. C'est plus proche d'un plan de controle produit que d'un serveur OpAMP minimal.

Mais le couplage apparait vite lui aussi.

Le chemin BDOT est le chemin naturel. L'installation depend d'un secret genere par Bindplane et d'une commande produit. En automation SSH, le script public a echoue sans `TERM`, puis a fonctionne avec `TERM=xterm`. Ce n'est pas grave en soi, mais c'est typique des details qu'il faut industrialiser avant de parler de parc.

Le test avec une distribution OCB custom a ete bloque: le collecteur demarrait, utilisait la forme WebSocket/documentee, les labels et un `instance_uid` ULID valide, mais Bindplane a retourne `403 Forbidden` pendant le handshake OpAMP. Les docs publiques indiquent que l'usage d'autres distributions OpenTelemetry est une fonction Enterprise/BYOC et que l'extension OpAMP standard peut etre limitee a la visibilite sans configuration distante. Dans l'etude, ce point devient une friction commerciale et fonctionnelle, pas seulement un probleme YAML.

La configuration distante est restee partielle: le builder source/destination a ete teste, la source File sauvegardee, mais le rollout complet vers une destination Elastic portable n'a pas ete termine. Le preset Elasticsearch OTLP ne correspondait pas directement au flux `ApiKey` Elastic du lab, car il demandait un APM URL et un secret token. Le chemin portable semble passer par une destination Custom avec YAML OTel brut, a tester proprement.

Conclusion Bindplane: plus fort en experience produit que le chemin ouvert minimal, mais la reversibilite depend de la capacite a exporter, reconstruire et automatiser les pipelines hors du modele produit.

## Ce que les plans manages apportent vraiment

Les plans manages ne doivent pas etre caricatures. Ils apportent des choses que les equipes sous-estiment souvent:

- onboarding guide par UI ou commande generee;
- inventaire lisible;
- statut connecte/deconnecte;
- details systeme et version;
- workflow de configuration plus proche des operateurs;
- support potentiel, documentation produit et surfaces commerciales claires.

Ces apports ont une valeur reelle. Pour beaucoup d'organisations, payer un produit pour absorber cette complexite est plus rationnel que construire une plateforme interne.

Mais les plans manages ne suppriment pas toutes les questions. Qui possede le packaging ? Comment automatiser la rotation des secrets ? Peut-on reproduire la configuration sous forme OTel YAML portable ? Que reste-t-il dans l'UI apres sortie ? Quelle API permet d'onboarder 10 000 agents sans clics ? Quels champs sont auditables ? Que se passe-t-il pendant une panne du plan de controle ?

## Le benchmark change le verdict OpAMP

Les benchmarks manages clarifient le role d'OpAMP. Ils montrent que la valeur entreprise n'est pas seulement de connecter un agent. La valeur est de produire une experience complete autour du parc.

Fleet OTel-only montre qu'un produit mature peut donner rapidement de la visibilite, tout en laissant encore beaucoup de lifecycle externe dans ce scenario. Bindplane montre qu'un produit specialise peut mieux encadrer la configuration, mais introduit un modele propre, des secrets propres et des limites de plan ou de distribution.

Pour OpAMP ouvert, la question devient concrete: quelles parties veut-on construire, et lesquelles veut-on acheter ? Si l'equipe choisit le chemin ouvert, elle doit accepter la charge de produit: UI, API, validation, rollout, auditabilite, secrets, nettoyage, montee en charge et support. Si elle choisit un plan manage, elle doit accepter les couts, le modele produit et le travail de reversibilite.

Ce n'est pas une opposition ideologique. C'est un arbitrage d'architecture.
