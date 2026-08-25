# FluxCloud iOS Client ☁️📱

Ein moderner, nativer iOS-Client (SwiftUI, iOS 16+) für **FluxCDN / FluxCloud**.

## 🚀 Features

- **Einfache Server-Anbindung**: Eingabe der Server-Adresse (HTTP / HTTPS) & des API-Keys mit automatischer Verbindungsprüfung.
- **Nativer Filebrowser**:
  - Hierarchische Ordnernavigation (Unterordner, Vor- und Zurück-Navigation).
  - Dateiliste mit Dateityp-Symbolen, Dateigröße und Änderungsdatum.
  - Bildvorschau / Thumbnails direkt in der Dateiliste.
  - Kategorien-Filter (Alle, Ordner, Bilder, Videos, Dokumente, Code).
  - Suchleiste mit Sofort-Filterung.
  - Pull-to-Refresh zum Aktualisieren der Dateiliste.
- **Datei-Details & Sharing**:
  - Detaillierte Datei-Informationen.
  - Download & Öffnen über das native iOS Share-Sheet (`UIActivityViewController`).
  - Download-Link in die Zwischenablage kopieren.
- **Automatischer IPA-Build**: GitHub Actions Workflow erstellt bei jedem Push automatisch eine unsignierte `.ipa`-Datei.

---

## 🛠 Voraussetzungen & Kompatibilität

- **iOS Version**: iOS 16.0 oder neuer
- **Backend**: FluxCDN Server mit aktivierter API
- **Sideloading-Tools**: AltStore, TrollStore, Sideloadly, LiveContainer, Scarlet o. ä.

---

## 📦 Automatische IPA Erstellung (GitHub Actions)

Bei jedem Push auf den `main`-Branch baut die GitHub Action `.github/workflows/build-ipa.yml` automatisch das Xcode-Projekt und erzeugt eine fertige `FluxCloud.ipa`.

1. Gehe in deinem GitHub Repository auf den Reiter **Actions**.
2. Klicke auf den letzten Durchlauf von **Build iOS IPA**.
3. Scrolle nach unten zum Bereich **Artifacts** und lade **FluxCloud-iOS-IPA** herunter.
4. Installiere die entpackte `FluxCloud.ipa` über AltStore / TrollStore / Sideloadly auf deinem iPhone.

---

## 💻 Lokale Entwicklung in Xcode

1. Klone das Repository:
   ```bash
   git clone https://github.com/F1mmel/FluxCloud_iOS.git
   ```
2. Öffne `FluxCloud.xcodeproj` in Xcode.
3. Wähle dein iOS-Gerät oder einen Simulator aus und starte die App mit `Cmd + R`.
