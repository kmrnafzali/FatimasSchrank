# Fatimas Schrank

Ein digitaler Kleiderschrank fürs iPhone (SwiftUI, iOS 17 oder neuer). Alle Daten bleiben auf dem Gerät.

## Installieren

1. Unter *Releases* die Datei `FatimasSchrank.ipa` laden. Sie wird bei jedem Push automatisch gebaut.
2. Mit AltStore installieren.

Die App-Kennung `de.kmrn.fatimasschrank` darf sich nie ändern, sonst gehen bei einem Update die Daten verloren.

## Bauen

Gebaut wird mit XcodeGen (`project.yml`) auf einem GitHub-macOS-Runner. Der Workflow legt außerdem Bildschirmfotos aus dem Simulator unter dem Release *vorschau* ab.

## Persönliche Texte

Widmung, Briefe und Karten stehen alle in `FatimasSchrank/Liebesbriefe.swift`.
