# Zeichensatz Tabelle für GeoWorks 1

Native 8086-Anwendung für das Ensemble 1.2 Profil des
[PC/GEOS 1 SDK](https://github.com/dnesbitt142/pcgeos-1-sdk-v2). Sie zeigt die
GEOS-Bytewerte `00` bis `FF` als 16×16-Raster. Druckbare Zeichen werden in der
ausgewählten Schrift gezeichnet; die Hexadezimalzahl jeder Zelle ist der
jeweilige GEOS-Zeichencode.

## Bedienung

- Zelle mit der Maus oder den Pfeiltasten auswählen.
- **Schrift F** oder **F** öffnet den Schriftartdialog mit Berkeley, Roman,
  Sans und Mono samt Schriftprobe. Mit Pfeil hoch/runter und Enter wählen;
  Esc schließt den Dialog. Ein Mausklick auf eine Schrift übernimmt sie sofort.
- **C** oder **Leertaste** kopiert ein druckbares Zeichen in die Zwischenablage.
- Steuerzeichen `00`–`1F` und `7F` sind als Code sichtbar und nicht kopierbar.

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

