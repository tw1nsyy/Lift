# LIFT — iOS Workout Tracker & Gym Log

SwiftUI · Observation · SwiftData · Swift Charts · iOS 17+ · Xcode 15+

## Запуск на Mac
`brew install xcodegen && cd LIFT && xcodegen && open LIFT.xcodeproj` → выбрать iPhone/симулятор → Run.
Тесты: Cmd+U.

## Запуск без Mac (Windows)
1. Залить проект на GitHub (ветка main).
2. Вкладка Actions → "iOS build" → скачать артефакт `LIFT-ipa` (неподписанный .ipa).
3. Установить через Sideloadly (sideloadly.io) со своим Apple ID. Бесплатный Apple ID = 7 дней.

## Структура
LIFT/            исходники приложения (Core, Models, Services, Views)
LIFTTests/       unit-тесты (формулы, рекорды, прогрессия, план)
.github/workflows/ios.yml   сборка .ipa и тесты в GitHub Actions
project.yml      описание проекта для XcodeGen
