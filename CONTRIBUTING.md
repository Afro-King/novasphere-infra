1. Une branche Git est créée pour chaque changement.
2. Aucun changement n’est poussé directement sur main.
3. Chaque pull request est relue avant le merge.
4. terraform fmt et terraform validate précèdent chaque commit.
5. Le plan Terraform est lu intégralement avant chaque apply.
6. Le state est partagé dans S3 et n’est jamais ajouté à Git.
7. Aucun force-unlock sans vérifier les opérations actives.
8. Aucun secret, tfvars, PEM ou identifiant AWS dans Git.
9. Le fichier .gitignore ne doit jamais être affaibli.
10. Détruire en fin de séance et publier le tag v5.<séance>.0. 
