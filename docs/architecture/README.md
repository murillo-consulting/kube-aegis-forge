# Architecture de kube-aegis-forge

[Ouvrir le HTML autonome](architecture.html) · [Spécification Archify](architecture.archify.json)

Télécharger le HTML et l'ouvrir localement dans un navigateur : GitHub affiche son code et ne l'exécute pas. Aucun hébergement supplémentaire n'est nécessaire.

Vue compacte des composants du dépôt au commit `6d01f679f5a05a67aabb32b5fcbc41b4bf7b65ee`. Les flèches représentent les opérations indiquées, pas une preuve de déploiement ni un graphe exhaustif des appels. Les composants secondaires sans flèche complètent l'inventaire ; leurs liens détaillés restent dans les sources ci-dessous.

Le lien CI → kind est omis : la CI ne déploie pas. AWS EKS est une extension hors de cette vue locale.

Le texte du diagramme est en français. Les commandes fixes du Viewer et l'attribut HTML `lang` restent en anglais, langue de repli d'Archify 2.17. Affichage statique initial, thèmes clair et sombre ; aucune animation activée.

![Aperçu de la carte](architecture-preview.png)

## Sources vérifiées

| Composant | Source au commit de référence |
| --- | --- |
| Livraison CI | [.github/workflows/release.yml:1–9](https://github.com/murillo-consulting/kube-aegis-forge/blob/6d01f679f5a05a67aabb32b5fcbc41b4bf7b65ee/.github/workflows/release.yml#L1-L9) |
| Argo CD | [platform/argocd/local/30-demo-api.yaml:10–18](https://github.com/murillo-consulting/kube-aegis-forge/blob/6d01f679f5a05a67aabb32b5fcbc41b4bf7b65ee/platform/argocd/local/30-demo-api.yaml#L10-L18) |
| Workload FastAPI | [platform/charts/demo-api/templates/deployment.yaml:2–10](https://github.com/murillo-consulting/kube-aegis-forge/blob/6d01f679f5a05a67aabb32b5fcbc41b4bf7b65ee/platform/charts/demo-api/templates/deployment.yaml#L2-L10) |
| Métriques | [platform/argocd/common/13-monitoring.yaml:12–20](https://github.com/murillo-consulting/kube-aegis-forge/blob/6d01f679f5a05a67aabb32b5fcbc41b4bf7b65ee/platform/argocd/common/13-monitoring.yaml#L12-L20) |
| Kyverno | [platform/policies/verify-image.yaml:2–10](https://github.com/murillo-consulting/kube-aegis-forge/blob/6d01f679f5a05a67aabb32b5fcbc41b4bf7b65ee/platform/policies/verify-image.yaml#L2-L10) |
| Cluster kind | [platform/kind/cluster.yaml:1–9](https://github.com/murillo-consulting/kube-aegis-forge/blob/6d01f679f5a05a67aabb32b5fcbc41b4bf7b65ee/platform/kind/cluster.yaml#L1-L9) |

## Reproduction

Prérequis : Node.js et le skill [Archify](https://github.com/tt-a1i/archify), version 2.17 (MIT). Depuis la racine du dépôt, remplacer `<ARCHIFY>` par le répertoire du skill installé :

```text
rtk node <ARCHIFY>/bin/archify.mjs validate architecture docs/architecture/architecture.archify.json --repo-root . --quality showcase --json
rtk node <ARCHIFY>/bin/archify.mjs deliver architecture docs/architecture/architecture.archify.json docs/architecture/architecture.html --repo-root . --quality showcase --json
rtk node <ARCHIFY>/bin/archify.mjs visual-check docs/architecture/architecture.html --json
```

La révision source doit être présente dans le clone pour vérifier les références. Après une modification du JSON, relancer les trois commandes puis inspecter les captures des deux thèmes. Ne pas éditer le HTML généré.

## Vérifications et limites

Validation et livraison : **9/9 contrôles showcase**, zéro erreur et zéro avertissement. Le reçu portable `acceptance.json` lie les octets exacts aux contrôles et distingue la preuve navigateur de la revue des images.

Les tests applicatifs ne sont pas relancés : seuls le JSON, le HTML, les preuves documentaires et le lien du README changent. Cette documentation n'établit pas la santé d'un service, la sécurité d'une installation ni une conformité réglementaire.

Retour arrière : retirer le lien du README et les cinq fichiers de cette documentation, ou révoquer son commit. Aucun changement applicatif ou déploiement n'est associé.
