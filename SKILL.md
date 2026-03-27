# Build Docker sous proxy MITM HTTPS

## Probleme

L'environnement de build utilise un proxy HTTPS qui fait du Man-In-The-Middle
(MITM) : il intercepte les connexions TLS et re-signe les certificats avec sa
propre CA. Cela pose plusieurs problemes lors du `docker build` :

1. **Les sources apt en HTTP sont bloquees** par le proxy (erreur `500 Internal
   Server Error` / `TooManyRequests`). Il faut utiliser HTTPS.

2. **Le certificat CA du proxy est perdu** apres l'installation du paquet
   `ca-certificates`, car `dpkg` regenere `/etc/ssl/certs/ca-certificates.crt`
   a partir du trust store systeme, ecrasant la version injectee par les hooks.

3. **`apt-get` ne peut pas acceder a certains repos tiers** meme en HTTPS,
   car le proxy retourne `400 Bad Request` pour ces URLs via le protocole apt.
   `curl` fonctionne pourtant pour les memes URLs.

## Contournements

### 1. Forcer HTTPS pour les sources Debian

Pour les images basees sur Debian trixie+ (qui utilisent le format DEB822) :

```dockerfile
RUN sed -i 's|http://|https://|g' /etc/apt/sources.list.d/debian.sources
```

Pour les images plus anciennes (format sources.list classique) :

```dockerfile
RUN sed -i 's|http://|https://|g' /etc/apt/sources.list
```

### 2. Reinstaller le CA du proxy apres ca-certificates

Les hooks injectent `COPY proxy-ca.crt /etc/ssl/certs/ca-certificates.crt` en
debut de Dockerfile, mais ca ne survit pas a l'installation de `ca-certificates`.

La solution : copier le cert dans le trust store et regenerer le bundle :

```dockerfile
COPY proxy-ca.crt /usr/local/share/ca-certificates/proxy-ca.crt
RUN apt-get update && apt-get install -yq ca-certificates curl ... \
    && update-ca-certificates \
    && rm -rf /var/lib/apt/lists/*
```

Apres `update-ca-certificates`, le bundle contient les CA systeme + le proxy CA,
et `curl` fonctionne pour tous les domaines HTTPS.

### 3. Telecharger les .deb avec curl au lieu d'apt

Pour les repos tiers dont `apt-get` ne peut pas acceder a travers le proxy,
telecharger les paquets directement avec `curl` et les installer avec `dpkg` :

```dockerfile
RUN mkdir -p /tmp/debs && \
    curl -fsSL -o /tmp/debs/mon-paquet.deb "https://repo.exemple.com/pool/mon-paquet_1.0_amd64.deb" && \
    dpkg -i /tmp/debs/mon-paquet.deb && \
    rm -rf /tmp/debs
```

Si le paquet a des dependances non satisfaites, lancer `apt-get install -f`
apres `dpkg -i` pour les resoudre.

`curl` utilise le protocole CONNECT a travers le proxy, ce qui fonctionne meme
quand apt echoue. La difference vient probablement du fait qu'apt envoie des
requetes HTTP specifiques que le proxy ne sait pas relayer correctement.

## Resume

| Probleme | Cause | Contournement |
|----------|-------|---------------|
| apt HTTP bloque | Proxy refuse HTTP | `sed -i 's\|http://\|https://\|g'` sur les sources |
| curl/pip SSL error apres ca-certificates | Bundle CA ecrase par dpkg | `COPY` dans `/usr/local/share/ca-certificates/` + `update-ca-certificates` |
| apt HTTPS 400 sur certains repos tiers | Proxy incompatible avec apt pour ce domaine | Telecharger les .deb avec `curl` + `dpkg -i` |
