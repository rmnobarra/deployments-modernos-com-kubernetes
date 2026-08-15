# GitOps Course Repository

Repositório de manifests Kubernetes gerenciados via GitOps.

## Estrutura

├── apps/                  # Uma pasta por aplicação, no padrão base + overlays
│   └── demo-app/          # (criada na Aula 02)
│       ├── base/          # Config comum a todos os ambientes
│       └── overlays/      # O ambiente vive AQUI, dentro da app
│           ├── dev/
│           ├── staging/
│           └── prod/
├── infra/                 # Infraestrutura (monitoring, ingress, sealed-secrets)
└── argocd-apps/           # Applications e ApplicationSets do ArgoCD (Aula 04+)

Cada ambiente é um overlay da aplicação, não um diretório de topo:
o caminho `apps/demo-app/overlays/prod` é exatamente o que a Application
do ArgoCD aponta em `spec.source.path`.
