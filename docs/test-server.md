# Testserver, Pfade

Diese Datei beschreibt, welche Adressen die App erwartet. Sie richtet den Server nicht ein und enthält keine Passwörter, keine Schlüssel und keine Konten. Konten werden getrennt ausgehändigt.

Ein Build ohne `--dart-define` bleibt bei `http://127.0.0.1:18008` (Homeserver) und `http://127.0.0.1:18018` (Policy). Klartext-HTTP ist nur für `127.0.0.1`, `localhost` und `::1` erlaubt. Jede andere Adresse muss `https` sein. Die Android-Netzwerkkonfiguration erlaubt Klartext ebenfalls nur für `127.0.0.1` und `localhost`. Für `hoobird.0xneoncode.de` gibt es keine Klartext-Ausnahme.

Der arm64-Debug-Build für das Xiaomi wird so erzeugt:

```bash
cd app
flutter build apk --debug --target-platform android-arm64 \
  --dart-define=HOOBIRD_HOMESERVER=https://hoobird.0xneoncode.de \
  --dart-define=HOOBIRD_POLICY_BASE=https://hoobird.0xneoncode.de/policy
```

`HOOBIRD_HOMESERVER` ist die Matrix-Basis. Das SDK hängt `/_matrix/...` daran. `HOOBIRD_POLICY_BASE` ist die Policy-Basis einschließlich des Pfadpräfixes `/policy`, ohne Schrägstrich am Ende. Die App hängt daran `/_hoobird/v1/...`. In der Adresse steht kein Benutzername und kein Passwort. Ein solcher Bestandteil wird abgelehnt.

## Was nginx zuordnen muss

Öffentlicher Name: `hoobird.0xneoncode.de`, nur TLS, Zertifikat, dem Android vertraut. `public_baseurl` von Synapse muss `https://hoobird.0xneoncode.de/` sein. `/.well-known/matrix/client` muss auf dieselbe HTTPS-Basis zeigen, sonst kann das SDK den Client auf eine andere Adresse ziehen. Der Matrix-Servername bleibt der, den die Policy bei der Anmeldung in der Nutzerkennung zurückgibt. Die App schreibt ihn nicht um.

Die Upstream-Adressen unten sind Loopback auf dem Rechner, auf dem Synapse und die Policy-API schon laufen. Sie sind keine öffentliche Adresse.

```nginx
server {
    listen 443 ssl;
    server_name hoobird.0xneoncode.de;

    location /.well-known/matrix/client {
        proxy_pass http://127.0.0.1:18008;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
    }

    location /_matrix/ {
        proxy_pass http://127.0.0.1:18008;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
        proxy_read_timeout 600s;
        client_max_body_size 50m;
    }

    # Der Schrägstrich am Ende von proxy_pass nimmt das Präfix /policy/ weg.
    # /policy/_hoobird/v1/login erreicht die Policy als /_hoobird/v1/login.
    location /policy/ {
        proxy_pass http://127.0.0.1:18018/;
        proxy_set_header Host $host;
        proxy_set_header X-Forwarded-Proto https;
    }
}
```

`/_matrix/` muss vollständig durchgereicht werden. Das SDK `matrix` 16.0.1 wählt die einzelnen Routen darunter, einschließlich `/_matrix/client/v3/` und Medien unter `/_matrix/client/v1/media/`. Diese Fassung ruft `/_synapse/` nicht auf. Die Sync-Anfrage bleibt lange offen. Ein kurzes Proxy-Timeout beendet sie.

`/.well-known/matrix/client` auf `hoobird.0xneoncode.de` darf fehlen. Wenn die Datei da ist, muss `m.homeserver.base_url` genau `https://hoobird.0xneoncode.de` sein. Ein anderer Wert zieht den Client weg. Nach der Anmeldung kann das SDK dieselbe Datei auch unter dem Matrix-Servernamen der Nutzerkennung abfragen. Der sichere Stand ist, dass dieser Servername `hoobird.0xneoncode.de` ist, oder dass die Datei dort auf dieselbe HTTPS-Basis zeigt. Die App schreibt den Servernamen nicht um.

## Pfade, die diese App selbst aufruft

Alle Policy-Aufrufe gehen an `https://hoobird.0xneoncode.de/policy` plus den Pfad. Die App sendet `Authorization: Bearer` mit dem Token aus der Anmeldung. Sie sendet kein Passwort an eine andere Route.

| Methode | Pfad an der öffentlichen Basis |
| --- | --- |
| POST | `/policy/_hoobird/v1/login` |
| GET | `/policy/_hoobird/v1/me` |
| GET | `/policy/_hoobird/v1/directory?q=` |
| GET | `/policy/_hoobird/v1/children/{childId}` |
| POST | `/policy/_hoobird/v1/children/{childId}/approvals` |
| DELETE | `/policy/_hoobird/v1/children/{childId}/approvals/{contactUserId}` |
| POST | `/policy/_hoobird/v1/children/{childId}/blocks` |
| DELETE | `/policy/_hoobird/v1/children/{childId}/blocks/{contactUserId}` |
| POST | `/policy/_hoobird/v1/children/{childId}/devices` |
| DELETE | `/policy/_hoobird/v1/children/{childId}/devices/{deviceId}` |
| POST | `/policy/_hoobird/v1/children/{childId}/link-codes` |
| POST | `/policy/_hoobird/v1/children/{childId}/parents` |
| POST | `/policy/_hoobird/v1/blocks` |
| POST | `/policy/_hoobird/v1/reports` |

Diese Fassung ruft nicht auf: `/_hoobird/health`, Konten anlegen, E-Mail, Passwort-Reset, die Listen- und Löschroute der persönlichen Sperre, und `.../blocks/.../reconcile`. Das Präfix `/policy/` reicht diese Routen mit durch, wenn ein anderer Client sie braucht.

Matrix-Aufrufe gehen an die Basis `https://hoobird.0xneoncode.de`, nicht unter `/policy`. Das SDK legt sie unter `/_matrix/`. Die Anmeldung des Matrix-Clients läuft nicht über `/_matrix/client/v3/login`. Die App holt das Token bei der Policy und übergibt es an das SDK.
