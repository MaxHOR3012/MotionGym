# Motion Gym Herborn

Statische Website zum Businessplan-Schulprojekt.

- `index.html` — Übersicht zum Businessplan (Idee, Standort, Markt, SWOT, Preise, Finanzierung)
- `rad.html` — Fitness-Rad: Glücksrad mit zehn Übungen für die Sportstunde

Beide Dateien sind eigenständig: kein Build, kein Server, keine externen Bilder.

## Auf GitHub Pages veröffentlichen

1. Auf github.com ein neues Repository anlegen, z. B. `motion-gym`.
2. „uploading an existing file" wählen und beide HTML-Dateien hochladen.
3. Im Repository auf **Settings → Pages** gehen.
4. Unter *Source* `Deploy from a branch` wählen, Branch `main`, Ordner `/ (root)`, speichern.
5. Nach ein bis zwei Minuten ist die Seite erreichbar unter
   `https://DEIN-BENUTZERNAME.github.io/motion-gym/`
   Das Rad liegt dann unter `.../motion-gym/rad.html`.

## iOS-Feature „Einnahmen"

Unter `iOS/Einnahmen/` liegt ein eigenständiges SwiftUI-Modul (iOS 17+) für ein privates Geld-Portfolio. Wie man es in Xcode einbindet, steht in `iOS/Einnahmen/README.md`.

## iPhone-Widget „Einnahmen“ (ohne Mac)

`scriptable/Einnahmen.js` ist ein Skript für die kostenlose App Scriptable: Widget für den Home-Bildschirm plus Mini-App zum Erfassen. Anleitung in `scriptable/README.md`.
