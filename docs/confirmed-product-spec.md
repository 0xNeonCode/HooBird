# Bestätigte Produktskizze

HooBird ist ein Arbeitstitel. Er ist nicht markenrechtlich geprüft und wird hier nicht als veröffentlichter Name behandelt. Die Zielgruppe sind Familien und Menschen, denen Privatsphäre wichtig ist. Der Dienst soll kostenlos sein. Es sind keine Abo-Einnahmen geplant. Ein späteres Deployment auf einem vorhandenen VServer ist vorgesehen und wird von diesem Prototyp nicht angefasst.

Die Oberfläche ist Deutsch. Helles und dunkles Erscheinungsbild folgen dem System und lassen sich manuell umstellen. Die visuelle Richtung ist warm, rund, lavendelfarben auf warmem Weiß, im Dunkeln pflaumenfarben. Das generierte Richtbild schrieb im dunklen Überblick fälschlich „Uhats“. Die Oberfläche verwendet „Chats“.

## Entschieden

- Android zuerst, mit Flutter. Dieselbe Kontoidentität soll im MVP auf mehreren Android-Geräten gleichzeitig angemeldet sein können.
- Anmeldung mit Nutzername. E-Mail ist optional. Es gibt keine SMS.
- Die E-Mail bestätigt nur, dass jemand das Postfach lesen kann. Sie beweist kein Alter und keine rechtliche Identität.
- Die Matrix-ID ist die stabile, undurchsichtige Kontokennung. Der sichtbare Nutzername ist veränderbar und eindeutig, aber er ist nicht die Matrix-ID und kein Login-Alias für beliebige Matrix-Clients.
- Gespräche, Gruppen, Bilder und Sprachnachrichten sind Ende-zu-Ende verschlüsselt. „Verschlüsselt“ und „Identität verifiziert“ sind getrennte Zustände.
- Ein persönlicher Sicherungsschlüssel verschlüsselt die Schlüsselkopie. Ohne diesen Schlüssel und ohne ein bereits vertrautes Gerät können Nachrichten unlesbar bleiben.
- Eine Sicherung der Server-Datenbank, der Mediendateien oder der Servergeheimnisse ist keine Sicherung der privaten Schlüssel. Eine Matrix-Schlüsselkopie allein stellt auch nicht jedes Ereignis und jede Mediendatei wieder her.
- Ein Kontorücksetzen darf alte Entschlüsselungsschlüssel und bestehendes Vertrauen nicht stillschweigend zurückgeben.
- Eltern legen ein Kinderkonto an und verknüpfen sich persönlich. Der Prototyp benutzt dafür einen kurzlebigen Code. Ein QR-Code ist nicht umgesetzt. Der Vorgang beweist keine Sorgeberechtigung.
- Höchstens zwei Eltern. Eine Freigabe genügt.
- Ein Kind schreibt direkt nur an Kontakte, die ein Elternteil freigegeben hat. Eine Gruppe ist nur zulässig, wenn alle anderen Beteiligten für dieses Kind freigegeben sind.
- Eine Sperre eines Elternteils gilt. Das andere Elternteil hebt sie nicht auf, indem es erneut freigibt.
- Jedes zusätzliche Kindergerät braucht die Freigabe eines verknüpften Elternteils. Die Regeln gelten kontoübergreifend auf jedem Gerät und müssen vom Server durchgesetzt werden, auch wenn ein generischer Client die Endpunkte direkt aufruft.
- Ein Kind, das irgendwo ein unabhängiges Erwachsenenkonto anlegt, lässt sich damit nicht verhindern.
- Es gibt keine Zusicherung über Alter, Nähe oder Sorgeberechtigung.
- Eltern lesen keine Nachrichten und erhalten keine Schlüssel.
- Neue Gruppenmitglieder bekommen die alte Historie nicht automatisch.
- Ein Empfänger, der etwas rechtmäßig entschlüsseln kann, kann den Inhalt außerhalb des Clients kopieren. Das verhindert keine Richtlinie.
- Löschen zieht keine Screenshots und keine bereits heruntergeladenen Dateien zurück.
- Eine Meldung verlangt, dass jemand ausgewählte verschlüsselte Nachweise ausdrücklich teilt. Der Server überwacht keinen Klartext.
- Für eine spätere erste Produktversion sind vorgesehen, in diesem Meilenstein aber nicht gebaut: Antworten mit Sprung, Reaktionen, sichtbare Bearbeitungen und Löschungen, Weiterleiten, Mehrfachauswahl, Suche, Anheften, Archiv, Stumm, Zustellung, optionale Lesebestätigung, Tippanzeige, Sprachvorschau mit Aufnahmeverriegelung und Wiedergabegeschwindigkeit, Bildvorschau mit Bildunterschrift und entferntem Standort-EXIF, Gruppenadmins, Erwähnungen, gesteuerte Einladungen, Blockieren und Melden in der Oberfläche.
- Später, nicht in der ersten Version: Umfragen, allgemeine Dateien, verschwindende Nachrichten, Anrufe.
- Kontaktverifikation in Person soll später die üblichen Matrix-Verfahren QR, SAS und Cross-Signing benutzen. Bluetooth wäre nur eine kurzlebige Zuordnung einer Sitzung und kein Nähebeweis. Beides ist in diesem Meilenstein nicht gebaut. Es wird keine eigene Kryptografie erfunden.

## Annahmen dieses Prototyps

Diese Punkte sind keine bestätigte Produktentscheidung. Sie sind die enge Auslegung, mit der der Server jetzt fehlschlägt, statt offen zu sein.

- Verknüpfte Eltern sind für das Kind erlaubt und können hier nicht gesperrt werden. Das macht sie nicht zu Mitgliedern der anderen Räume des Kindes.
- Nur das Elternteil, das eine Sperre gesetzt hat, kann genau diese Sperre aufheben. Haben beide gesperrt, müssen beide ihre eigene Sperre aufheben.
- Jedes verknüpfte Elternteil darf eine Freigabe oder ein Gerät widerrufen.
- Es gibt keine Selbstbedienung, mit der ein verlorenes Elternkonto wiederhergestellt wird.
- Ein Passwort-Reset ist nur für ein Kinderkonto durch ein verknüpftes Elternteil möglich. Er meldet Geräte ab, behält die Gerätefreigaben, ändert die Matrix-ID nicht und gibt weder den Sicherungsschlüssel noch Cross-Signing-Schlüssel zurück.
- Das erste Kindergerät ist nicht implizit erlaubt. Es muss bei der Anlage oder danach freigegeben werden.
- Die Gerätefreigabe bindet die Zeichenkette der Gerätekennung, nicht den kryptografischen Fingerabdruck. Wer das Passwort kennt und eine bereits freigegebene Kennung mitbringt, kann diese Sitzung übernehmen.
- Räume werden serverseitig auf nur eingeladene Mitglieder, Historie „joined“, kein Gastzugang, kein Föderieren und Megolm festgelegt.
- Klartext-Ereignisse der Typen `m.room.message`, `m.reaction`, `m.sticker` und Umfragen werden abgelehnt. `m.room.encrypted` muss die Megolm-Struktur tragen. Das prüft die Form, nicht die kryptografische Gültigkeit.
- Ein Medien-Upload, dessen erste Bytes wie JPEG, PNG, GIF, Ogg, ID3, PDF, RIFF, WebM oder MP4 aussehen, wird abgelehnt. Das ist eine Heuristik und kein Beweis, dass der Rest verschlüsselt ist.
- Wenn die Richtliniendatenbank nicht erreichbar ist, wird abgelehnt.
- Richtlinie und Synapse sind keine gemeinsame Transaktion. Eine gleichzeitige Sperre und Einladung kann die Mitgliedschaft noch zulassen. Der folgende Inhaltsversuch muss dann scheitern. Es gibt keinen automatischen Rauswurf. Das ist ein Vorschlag für das Verhalten, keine bestätigte Oberfläche.
- Die Verknüpfung in Person ist ein einmaliger Code mit kurzer Gültigkeit, kein QR-Code.
- Der Bootstrap-Admin ist ein Betreiberkonto. Er kann Eltern- und Erwachsenenkonten anlegen, aber kein Kinderkonto, und er hat keine Schnittstelle zum Entschlüsseln.

## Offen

- Wer ein verlorenes Elternkonto wiederherstellt, und ob ein Elternteil sich einseitig lösen darf.
- Ob eine Gerätefreigabe später an einen Schlüsselfingerabdruck gebunden wird.
- Die Oberfläche, wenn eine Kindergruppe später eine nicht freigegebene Person bekommen würde. Der Prototyp lehnt die neue Mitgliedschaft und neuen Inhalt ab und entfernt das Kind nicht von selbst.
- Ob die Verknüpfung als QR, als Code oder als beides erscheint.
- Push ohne Klartext.
- Echter E-Mail-Versand. Der lokale Token beweist hier nur die Schleife.
- Ob die Nutzersuche zu leicht verrät, dass ein Name existiert.
- Das Format einer Meldung mit ausgewählten verschlüsselten Nachweisen.
- Markenprüfung und ein öffentlicher Name.
