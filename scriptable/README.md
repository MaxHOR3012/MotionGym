# Einnahmen – Widget fürs iPhone (Scriptable)

Ein Widget für den Home-Bildschirm mit deinen Monatseinnahmen. Antippen öffnet eine kleine App
zum Erfassen und Auswerten. Kein Mac nötig, keine Server, keine Tracker.

## Installation (ca. 5 Minuten)

1. **Scriptable** aus dem App Store installieren (kostenlos, von Simon B. Støvring).
2. **Skript aufs iPhone bringen**, eine der beiden Varianten:
   - **Datei sichern:** `Einnahmen.js` auf dem iPhone öffnen → Teilen → „In Dateien sichern“ →
     **iCloud Drive › Scriptable**. Das Skript erscheint dann automatisch in Scriptable.
   - **Kopieren:** Den Inhalt von `Einnahmen.js` komplett kopieren, in Scriptable oben rechts
     auf „+“ tippen, einfügen, oben den Namen auf **Einnahmen** ändern, „Fertig“.
3. **Einmal starten:** In Scriptable auf „Einnahmen“ tippen → „Leer starten“ oder
   „Mit Beispieldaten ausprobieren“.
4. **Widget hinzufügen:** Home-Bildschirm lange drücken → „Bearbeiten“ → „Widget hinzufügen“ →
   **Scriptable** → Größe wählen (klein, mittel oder groß) → „Widget hinzufügen“.
5. **Widget einrichten:** Das neue Widget antippen (im Bearbeiten-Modus) →
   - **Script:** Einnahmen
   - **When Interacting:** Run Script
   - **Parameter:** leer lassen oder `privat` eintragen, damit das Widget Beträge immer ausblendet

Fürs Sperrbildschirm-Widget: Sperrbildschirm lange drücken → „Anpassen“ → Widgets → Scriptable.

## Bedienung

- **Widget antippen** öffnet das Menü:
  - ➕ Einnahme erfassen (Quelle, Betrag, Notiz, Datum)
  - 📊 Übersicht & Diagramme (Balken pro Monat, Kreisdiagramm nach Quelle, Monatsziel)
  - 📋 Alle Einnahmen (antippen zum Ändern oder Löschen)
  - 🔁 Wiederkehrende Einnahmen (monatlich, vierteljährlich, jährlich; werden 12 Monate
    im Voraus geplant und am Fälligkeitstag automatisch verbucht)
  - 💼 Portfolio: Positionen anlegen und Dividenden/Zinsen mit einem Tipp verbuchen
  - 🙈 Beträge ausblenden
  - ⚙️ Einstellungen: Monatsziel, Widget-Vorschau, Speicherort, Daten löschen
- **Mittleres Widget:** Der Knopf „Erfassen“ springt direkt zur Eingabe.

## Gut zu wissen

- **Speicherort:** `iCloud Drive › Scriptable › einnahmen-daten.json`, mit Sicherungskopie
  `einnahmen-daten.backup.json`. Ist iCloud aus, liegt die Datei lokal in Scriptable.
- **Aktualisierung:** iOS entscheidet selbst, wann Widgets neu geladen werden. Neue Einträge
  erscheinen meist nach ein paar Minuten im Widget.
- **Face ID:** Scriptable selbst bietet kein Face ID. Ab iOS 18: Scriptable-Symbol lange
  drücken → „Face ID anfordern“.
- **Update:** Neue Version einfach über die alte Datei kopieren. Die Daten bleiben erhalten,
  weil sie in einer eigenen Datei liegen.
