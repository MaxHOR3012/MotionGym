# Einnahmen – SwiftUI-Feature für ein privates Geld-Portfolio

iOS 17+ · SwiftUI · SwiftData (optional iCloud/CloudKit) · Swift Charts · WidgetKit · Face ID
Deutsche Oberfläche, Währungsformat de-DE, Hell- und Dunkelmodus, komplett offline, keine Tracker.

## Ordnerstruktur und Target-Zugehörigkeit

| Datei | App | Widget | Zweck |
|---|:-:|:-:|---|
| **Shared/** | | | |
| `AppGroup.swift` | ✅ | ✅ | App-Group-ID und Einstellungs-Schlüssel |
| `Money.swift` | ✅ | ✅ | Cent ↔ €, de-DE-Formatierung, Eingaben parsen |
| `CalendarHelpers.swift` | ✅ | ✅ | Monatsanfang, Tagesende |
| `IncomeWidgetSnapshot.swift` | ✅ | ✅ | Monatssummen für das Widget |
| **App/Models/** | | | |
| `IncomeSource.swift` | ✅ | | Quellen (Gehalt, Dividende, Zinsen, Miete, Verkauf, Sonstiges) |
| `RecurrenceInterval.swift` | ✅ | | Monatlich / vierteljährlich / jährlich + Terminberechnung |
| `Income.swift` | ✅ | | SwiftData-Modell: einzelne Einnahme |
| `RecurringIncome.swift` | ✅ | | SwiftData-Modell: wiederkehrende Serie |
| `PortfolioPosition.swift` | ✅ | | SwiftData-Modell: Position (Aktie, ETF, Tagesgeld …) |
| `IncomeModelContainer.swift` | ✅ | | Container lokal oder mit CloudKit |
| **App/Services/** | | | |
| `RecurrenceService.swift` | ✅ | | Vorausplanung, Verbuchen am Fälligkeitstag, Duplikate entfernen |
| `BiometricAuthService.swift` | ✅ | | Face ID / Touch ID / Gerätecode |
| `WidgetSync.swift` | ✅ | | Schreibt den Snapshot und lädt das Widget neu |
| **App/ViewModels/** | | | |
| `IncomeStatistics.swift` | ✅ | | Monatssumme, Vormonatsvergleich, Jahr, Ø, Diagrammdaten |
| `IncomeDashboardViewModel.swift` | ✅ | | Zustand der Übersicht |
| `IncomeEditorViewModel.swift` | ✅ | | Erfassen/Bearbeiten (einmalig, Serie, aus Portfolio) |
| `IncomeListViewModel.swift` | ✅ | | Suche, Filter, Gruppierung nach Monat |
| **App/Views/** | | | |
| `IncomeRootView.swift` | ✅ | | Einstieg: Face-ID-Sperre, Aktualisieren beim Öffnen |
| `IncomeDashboardView.swift` | ✅ | | Übersicht |
| `IncomeEditorView.swift` | ✅ | | Formular |
| `IncomeListView.swift` | ✅ | | Alle Einnahmen |
| `RecurringIncomeListView.swift` | ✅ | | Serien: bearbeiten, pausieren, löschen |
| `GoalEditorView.swift` | ✅ | | Monatsziel |
| `IncomeSettingsView.swift` | ✅ | | Privatsphäre, iCloud, Datenschutz |
| `LockScreenView.swift` | ✅ | | Sperrbildschirm + Sichtschutz im App-Umschalter |
| `Components/*` | ✅ | | Karten, Betrag (ausblendbar), Kennzahlen, Fortschritt |
| `Charts/*` | ✅ | | Balken pro Monat, Ring nach Quelle |
| `Portfolio/*` | ✅ | | Positionen, Ausschüttung verbuchen |
| **App/Preview/** `PreviewData.swift` | ✅ | | Beispieldaten für alle `#Preview`s |
| `App/EinnahmenApp.swift` | ✅ * | | Nur bei neuem Projekt (siehe unten) |
| **Widget/** | | | |
| `IncomeWidget.swift` | | ✅ | Widget (Home- und Sperrbildschirm) |
| `IncomeWidgetBundle.swift` | | ✅ * | Nur bei neuer Widget-Extension |
| `Resources/PrivacyInfo.xcprivacy` | ✅ | ✅ | Datenschutz-Manifest (App Store) |

## Einbinden in Xcode (Schritt für Schritt)

### 1. Dateien hinzufügen
1. Den Ordner `iOS/Einnahmen` in den Xcode-Projektnavigator ziehen.
2. Im Dialog **„Copy items if needed"** und **„Create groups"** wählen.
3. Bei **Add to targets** zunächst nur das App-Target anhaken.
4. Danach die vier Dateien in `Shared/` auswählen und im Datei-Inspektor (⌥⌘1)
   unter **Target Membership** zusätzlich die Widget-Extension anhaken.
5. Die Dateien in `Widget/` gehören **nur** zur Widget-Extension.

### 2. Bestehende App oder neues Projekt?
- **Neues Projekt:** `EinnahmenApp.swift` behalten und die von Xcode erzeugte
  `…App.swift` sowie `ContentView.swift` löschen.
- **Bestehende App:** `EinnahmenApp.swift` **nicht** hinzufügen. Stattdessen in deiner App:

  ```swift
  WindowGroup {
      TabView {
          // … deine bisherigen Tabs
          IncomeRootView()
              .tabItem { Label("Einnahmen", systemImage: "eurosign.circle") }
      }
  }
  .modelContainer(IncomeModelContainer.make())
  ```

  Nutzt du bereits SwiftData, nimm `Income.self`, `RecurringIncome.self` und
  `PortfolioPosition.self` in dein bestehendes `Schema` auf, statt einen zweiten Container
  anzulegen. Hast du schon ein eigenes Positions-Modell, ergänze dort die Beziehungen
  `incomes` und `recurringIncomes` (siehe `PortfolioPosition.swift`) und ändere den Typ von
  `Income.position` und `RecurringIncome.position` auf dein Modell.

### 3. Widget-Extension anlegen (falls noch nicht vorhanden)
1. **File → New → Target… → Widget Extension**, Name z. B. `EinnahmenWidget`.
   „Include Live Activity" und „Include Configuration App Intent" **abwählen**.
2. Die von Xcode erzeugten Swift-Dateien der Extension löschen und
   `Widget/IncomeWidget.swift` sowie `Widget/IncomeWidgetBundle.swift` verwenden.
3. Hast du bereits ein Widget-Bundle: nur `IncomeWidget()` in dessen `body` eintragen.

### 4. Capabilities (Signing & Capabilities → „+ Capability")
| Capability | App | Widget | Einstellung |
|---|:-:|:-:|---|
| **App Groups** | ✅ | ✅ | z. B. `group.de.meinname.finanzen` in **beiden** Targets identisch |
| **iCloud** | ✅ | | Haken bei **CloudKit**, Container anlegen (z. B. `iCloud.de.meinname.finanzen`) |
| **Background Modes** | ✅ | | Haken bei **Remote notifications** (für CloudKit-Push) |

Danach in `Shared/AppGroup.swift` die Konstante `identifier` auf deine App-Group-ID setzen.

> Ohne iCloud-Capability funktioniert alles rein lokal; der Schalter „iCloud-Synchronisierung"
> hat dann keine Wirkung.

### 5. Info.plist (App-Target → Reiter „Info")
| Schlüssel | Wert |
|---|---|
| `Privacy - Face ID Usage Description` (`NSFaceIDUsageDescription`) | `Deine Einnahmen werden mit Face ID geschützt.` |
| `Localization native development region` (`CFBundleDevelopmentRegion`) | `de` |

Unter **Project → Info → Localizations** „German" hinzufügen und als Entwicklungssprache festlegen,
damit Systemtexte wie Datumsauswahl und Swipe-Aktionen auch auf Deutsch erscheinen.

### 6. Datenschutz-Manifest
`Resources/PrivacyInfo.xcprivacy` beiden Targets zuordnen. Hast du schon ein Manifest,
den Eintrag `NSPrivacyAccessedAPICategoryUserDefaults` (Gründe `CA92.1`, `1C8F.1`) dort ergänzen.

### 7. Bauen und testen
- Vorschau: z. B. `IncomeDashboardView.swift` öffnen, Canvas mit ⌥⌘↩ anzeigen
  (Beispieldaten über 13 Monate, Hell- und Dunkelmodus).
- Widget: App einmal starten (schreibt den Snapshot), dann auf dem Home-Bildschirm
  lange drücken → „+" → „Einnahmen".
- iCloud-Sync auf einem echten Gerät mit iCloud-Konto testen. Für die Produktion im
  [CloudKit-Dashboard](https://icloud.developer.apple.com) das Schema einmal von
  „Development" nach „Production" übernehmen.

## Wie es funktioniert

- **Beträge** werden als ganze Cent (`Int`) gespeichert: keine Rundungsfehler, CloudKit-tauglich.
- **Wiederkehrende Einnahmen** sind Serien (`RecurringIncome`). Beim Öffnen der App legt
  `RecurrenceService` die Termine für 12 Monate im Voraus an (als „erwartet") und verbucht
  fällige Termine automatisch. Ändern einer Serie baut nur die zukünftigen Termine neu auf,
  Vergangenes bleibt unverändert. Manuell gelöschte Termine kommen nicht zurück.
  Jeder Termin hat einen eindeutigen Schlüssel, sodass bei iCloud-Sync zwischen zwei Geräten
  keine Duplikate stehen bleiben.
- **Kennzahlen**
  - *Diesen Monat*: alle Einnahmen des laufenden Monats (eingegangen und erwartet; der erwartete
    Teil wird separat angezeigt).
  - *Vergleich*: gegenüber dem gesamten Vormonat in Prozent.
  - *Jahr*: 1. Januar bis Monatsende.
  - *Ø pro Monat*: Jahressumme geteilt durch die Monate seit Januar (bzw. seit der ersten Einnahme).
- **Portfolio:** in der Positionsliste nach rechts wischen → „Dividende"/„Zinsen" öffnet das
  Formular mit Position, Quelle und dem letzten Betrag vorbelegt.
- **Privatsphäre:** Tipp auf die Monatssumme oder das Auge in der Toolbar blendet alle Beträge
  aus (auch im Widget). Mit aktivem Face-ID-Schutz wird beim Wechsel in den Hintergrund gesperrt
  und der App-Umschalter-Screenshot verdeckt.
- **Widget:** liest nur einen kleinen Snapshot aus der App-Group (keine Datenbank, kein iCloud
  im Widget) und schaltet am Monatsersten automatisch auf den neuen Monat um.

## Hinweise
- Geschrieben für Swift 5 Language Mode (Xcode-Standard). Wenn dein Projekt
  „Default Actor Isolation = MainActor" oder Swift 6 nutzt, können im Widget-Target
  Concurrency-Warnungen auftauchen. Dann `IncomeTimelineProvider` mit `nonisolated`
  kennzeichnen oder die Einstellung für die Extension auf `nonisolated` stellen.
- Der iCloud-Schalter wirkt nach einem Neustart der App, weil der SwiftData-Container nur
  beim Start erzeugt wird.
