# Zeichensatz Tabelle für GeoWorks 1

Native 8086-Anwendung für das Ensemble 1.2 Profil des
[PC/GEOS 1 SDK](https://github.com/dnesbitt142/pcgeos-1-sdk-v2). Sie zeigt die
GEOS-Bytewerte `00` bis `FF` als 16×16-Raster. Druckbare Zeichen werden in der
ausgewählten Schrift und vergrößert gezeichnet. In den Rasterzellen erscheinen
keine Hexcodes; der Code des markierten Zeichens steht unten neben der Auswahl.
Status, Buildkennung und das Label „Zeichensatz:“ bleiben in Berkeley. Der Name der
aktiven Schrift wird größer in dieser Schrift dargestellt.

## Bedienung

- Zelle mit der Maus oder den Pfeiltasten auswählen.
- Das native Menü **Schrift** in der GeoWorks-Menüleiste enthält die Einträge
  **Berkeley**, **Roman**, **Sans** und **Mono**. Wähle einen Eintrag, um die
  Zeichentabelle mit dieser Schrift neu aufzubauen. **Weitere Schriften...**
  öffnet die scrollbare Schriftenliste mit Vorschau, **Übernehmen** und
  **Schließen**. Die Fontnamen stammen aus der installierten `FONT`- und
  `FONT_EURO`-Dateiliste der hier verwendeten GeoWorks-Installation.
- **C** oder **Leertaste** kopiert ein druckbares Zeichen in die Zwischenablage.
- Steuerzeichen `00`–`1F` und `7F` sind als Code sichtbar und nicht kopierbar.
- Beim Start ist `A` ausgewählt, damit der Kopierknopf direkt mit einem
  druckbaren Zeichen geprüft werden kann. Der Status zeigt Kopiererfolg oder
  einen Clipboard-Fehler an.
- **Datei** enthält Zeichentabelle, Zeichen kopieren, Info und Hilfe.
- Unter dem Raster gibt es zusätzlich echte GEOS-Schaltflächen für **Weitere
  Schriften** und **Zeichen kopieren**. Die Schriftzeile zeigt den Namen der ausgewählten Schrift groß in deren Schrift;
  bei LED- und Symbolfonts bleibt der Name zur Lesbarkeit in Berkeley.
- Die Buildkennung steht nur auf der Info-Seite.
- Das Layout ist auf einen Inhaltsbereich von 540 × 390 Punkten für VGA
  640 × 480 ausgelegt.
- Die Fontliste enthält 105 unterschiedliche Font-IDs aus den bei dieser
  Installation vorhandenen `.FNT`-Dateien. Sie ist ein Snapshot; neue
  Fontdateien erfordern eine Aktualisierung von `app/fontlist.inc`.

Die Zeichentabelle zeigt die Bytewerte des deutschen GeoWorks-1-Zielsystems.
Sie ist keine Unicode-Tabelle.

## Bauen

Voraussetzung ist eine eingerichtete `pcgeos-1-sdk-v2`-Umgebung. Unter Linux
oder WSL:

```sh
SDK=/pfad/zu/pcgeos-1-sdk-v2 ./build.sh
```

Das Ergebnis liegt unter `out/ZGTAB.GEO`. Für Installation GeoWorks sauber
beenden, die Datei nach `GEOWORKS/WORLD` einer Testinstallation kopieren,
GeoWorks neu starten und die App im GeoManager öffnen.

Das Projekt verwendet den SDK-Adapter `ensemble12` (Kernel 622.3, UI 693.0)
und 8086-NASM. `native_runtime_tested` ist noch nicht gesetzt: Der Quellstand
muss mit dem SDK gebaut und anschließend in der passenden GeoWorks-1-Runtime
interaktiv geprüft werden.

