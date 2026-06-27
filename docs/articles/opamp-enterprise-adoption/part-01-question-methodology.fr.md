---
series: opamp-enterprise-adoption
part: 1
language: fr
status: draft
evidence_review: complete
contradictory_review: complete
---

# OpAMP et l'adoption entreprise, partie 1: la mauvaise premiere question

Dans beaucoup de projets d'observabilite, la discussion commence par une question simple: quel collecteur faut-il installer ?

Pour un petit parc, cette question peut suffire. Pour une organisation de reference qui vise environ 100 000 actifs on-premises, c'est trop tard dans le raisonnement. Le vrai sujet n'est pas seulement le binaire qui lit un fichier de logs. Le vrai sujet est le plan de controle: comment identifier les agents, pousser une configuration, prouver qu'elle est appliquee, detecter les echecs, organiser les vagues de deploiement, changer les secrets, gerer la reversibilite et conserver une preuve exploitable.

Cette serie part donc d'une question plus utile: OpAMP est-il pret pour les grandes entreprises, ou reste-t-il un protocole a productiser par des equipes expertes et des editeurs ?

La reponse ne peut pas etre un slogan. OpAMP apporte une primitive importante: un protocole ouvert pour administrer des agents. Mais un protocole n'est pas automatiquement une plateforme de gestion de parc. La methode de l'etude consiste a separer ce qui est prouve en laboratoire, ce qui vient de la documentation publique, ce qui n'a pas ete teste, et ce qui reste bloque.

## Le scenario: logs-only, pas observabilite totale

Le profil d'entreprise utilise ici est fictif et public-safe. Il represente un grand parc on-premises avec centres de donnees, sites distants, reseaux segmentes, systemes d'exploitation mixtes et controles de sortie stricts. La cible d'architecture est un ordre de grandeur de 100 000 actifs, mais ce chiffre n'est pas un resultat de test. Il sert a forcer les bonnes questions d'architecture: cohortes, passerelles regionales, tempetes de reconnexion, auditabilite, rotation des secrets et montee en charge du plan de controle.

La premiere version du laboratoire est limitee aux logs. Ce choix est volontaire. Les logs suffisent a tester un chemin de donnees utile, tout en evitant de melanger trop vite metriques, traces, profiling, securite endpoint et instrumentation applicative. Le laboratoire peut alors se concentrer sur les questions qui cassent les projets a grande echelle:

- l'agent est-il visible avec une identite stable ?
- le plan de controle voit-il l'etat reel du collecteur ?
- une configuration distante peut-elle etre assignee, appliquee et auditee ?
- une mauvaise configuration est-elle bloquee, signalee ou simplement subie ?
- que se passe-t-il si le plan de controle tombe ?
- comment sortir d'un plan de controle manage vers un chemin OpAMP ouvert ?

Le chemin de donnees est volontairement simple: un collecteur lit des logs synthetiques et exporte vers un backend commun. Dans le laboratoire, Elastic Cloud sert de destination pratique pour valider l'ingestion, faire des recherches et capturer des tableaux de bord. Ce choix ne transforme pas Elastic en architecture de production obligatoire. Il donne un point de comparaison commun.

Un schema de reference peut accompagner cette partie avec `assets/diagrams/lab-topology.png` et `assets/diagrams/enterprise-100k-reference.png`: le premier montre le lab reduit, le second montre pourquoi un parc de reference demande des cohortes, des passerelles et un plan d'audit.

## Les candidats ne sont pas au meme niveau

Une confusion frequente consiste a comparer OpAMP, Fleet, OCB et une distribution Collector comme s'il s'agissait de produits equivalents. Ce n'est pas le cas.

OpAMP est un protocole de gestion d'agents. Fleet est un plan de controle produit pour Elastic Agent, et le laboratoire teste aussi un mode Fleet avec collecteur OpenTelemetry sans Elastic Agent. OCB sert a construire une distribution OpenTelemetry Collector reduite. EDOT et `otelcol-contrib` sont des distributions de collecteur. Bindplane est un produit de gestion de pipelines et de collecteurs.

La serie compare donc des chemins operationnels, pas seulement des composants:

- un chemin OpAMP ouvert, base sur `opamp-go`, un agent superviseur et un collecteur OCB ou `otelcol-contrib`;
- un chemin Python OpAMP, utile pour comprendre ce qu'un serveur plus petit peut accelerer mais aussi ce qu'il faut renforcer;
- Elastic Fleet en mode OpenTelemetry only, comme benchmark de visibilite managee;
- Bindplane avec BDOT, comme benchmark de workflow produit autour du Collector;
- les distributions Collector comme surface de chemin de donnees, et non comme plan de controle complet.

Cette distinction change le verdict. Un collecteur peut etre excellent et laisser l'equipe sans solution de parc. Un produit peut simplifier l'onboarding et rendre la sortie plus couteuse. Un protocole ouvert peut reduire le verrouillage fournisseur tout en deplacant beaucoup de charge produit vers l'equipe interne.

## Les etiquettes de preuve

Pour eviter de transformer des hypotheses en conclusions, chaque affirmation doit porter une etiquette.

`source-only` signifie que la documentation publique ou le code source de reference soutient l'affirmation, mais que le laboratoire ne l'a pas encore reproduite.

`lab-proven` signifie que le laboratoire a reproduit le comportement avec des versions epinglees, des commandes, des configurations redigees, des captures ou des resultats conserves.

`not-tested` signifie que le sujet est volontairement hors perimetre a ce stade.

`blocked` signifie que le test etait prevu, mais qu'il a ete bloque par une limite d'acces, de licence, de configuration, de fonctionnalite ou de reproductibilite.

Cette discipline est contraignante, mais elle est necessaire. Par exemple, le laboratoire peut dire que Fleet OTel-only a montre un collecteur `otelcol-contrib` visible, sain et capable d'envoyer des logs dans le backend commun. Il ne peut pas dire que Fleet a fourni une gestion complete de configuration distante pour ce collecteur, car le run a montre une configuration effective visible mais pas de chemin editable de policy distante pour ce flux.

De la meme maniere, l'architecture de reference 100k n'est pas un test 100k. C'est une cible conceptuelle pour verifier que les choix faits dans le lab n'ignorent pas la montee en charge.

## Le demarrage du lab

Le lab commence modestement. Un collecteur lit des logs synthetiques. Les donnees arrivent dans Elastic Cloud. Les preuves sont redigees sous forme de runbooks, resultats CSV, captures sanitisees et notes d'ecart.

Les premiers runs montrent deja pourquoi la question "quel collecteur ?" est insuffisante. Le collecteur peut fonctionner, mais l'identite peut etre instable. Le plan de controle peut voir une ligne saine, mais laisser des lignes obsoletes apres redemarrage ou sortie. Une interface peut afficher l'etat, mais ne pas fournir le workflow de rollout attendu. Un serveur OpAMP minimal peut accepter des connexions, mais manquer d'auditabilite, de validation de secrets ou de nettoyage d'inventaire.

La promesse d'OpAMP reste importante: il donne une base ouverte pour connecter des agents a un plan de controle. Mais l'adoption entreprise depend de tout ce qui l'entoure: produit, securite, UI, API, persistance, validation, rollback, exploitation et preuve.

La suite de la serie suit cette progression. Partie 2: construire le chemin OpAMP ouvert. Partie 3: comparer les plans de controle manages. Partie 4: tester la sortie, les secrets et la panne. Partie 5: formuler un verdict entreprise.
