# BusNow!! iOS（個人利用）

iPhone 単体で動く SwiftUI アプリです。接近と時刻表は端末から公式ページを直接取ります。バックエンドはありません。Web 版（リポジトリ直下の Next.js）とは別物で、`ios/` だけを変更します。

App Store への公開用には作っていません。東急バスの時刻表サイトは自動取得を禁止しており、ガイドライン 4.2 / 5.2.2 の観点でもストア申請は見送りです。想定は本人のシミュレータ確認と、必要なら TestFlight の個人利用です。署名チームは入れていません。

シミュレータの CI は `CODE_SIGNING_ALLOWED=NO` と空の Development Team でビルドします。実機や TestFlight に載せるときは、Xcode で自分の Apple ID の Team を選び、署名をオンにしてください。このリポジトリは端末向けの署名設定を入れていません。

## 構成

- `Package.swift` … `BusNowCore`。Foundation のみ。UIKit / SwiftUI には依存しません。
- `Sources/BusNowCore` … カウントダウン、東京の暦、HTML パーサ、東急バスナビ / 川崎市バスナビ / 時刻表、オフラインの保存。
- `BusNowApp/` … SwiftUI。iOS 17 以上。表示名は BusNow!!、bundle id は `app.busnow.ios`。

ロジックのテストは `swift test --package-path ios` で Linux でも通ります。画面のテストは `BusNowApp/BusNow.xcodeproj` の scheme `BusNow` を iOS シミュレータで `xcodebuild test` します。

プレビュー用の起動引数（ネットワークもカウントダウンも止めます。時計は 2026-10-17 10:30 JST）:

- `-busnow-scenario home|approach|approach-partial|approach-empty|approach-down|approach-failed|departures|departures-finished|departures-down`
- `-busnow-start approach|departures`

## この環境で確認したこと

- 2026-10-17 に `https://transfer.navitime.biz` の東急バス時刻表を取りにいくと CloudFront が HTTP 403（Request blocked）を返しました。同梱の `Sources/BusNowCore/Resources/tokyu-mizonokuchi.json` は Web 版と同じ **2025-07-01 改定**のままです。確認日は 2026-10-17、最新かどうかは未確認です。ライブが取れないときは、その改定日と「現在のダイヤと異なる可能性があります」「2026年10月17日時点では最新かどうか確認できていません」を画面に出します。
- HTML は SwiftSoup ではなく、Foundation だけで動く自前パーサです。Linux の `swift test` を UIKit なしで回すためです。フィクスチャ（東急バスナビ、川崎市バスナビ、NAVITIME の表、川崎市バスの時刻表）で Web 版と同じ結果になることをテストしています。
- Shift_JIS は `Resources/cp932.bin`（WHATWG / Python の cp932、9604 組）でデコードします。Linux に `String.Encoding.shiftJIS` が無くても、iOS と同じ結果になります。

## 色

看板はダークモードでもクリーム色のままです（`preferredColorScheme(.dark)` と `UIUserInterfaceStyle = Dark` はクロム用）。コントラストは次のとおりです。

| 組み合わせ | 比 | 使い方 |
| --- | --- | --- |
| `#241c16` on `#f6efe2` | 14.66:1 | 本文 |
| `#e25b2a` on `#f6efe2` | 3.19:1 | 大きい「まもなく」だけ |
| `#1f4b6e` on `#f6efe2` | 8.02:1 | 時刻、リンク |
| 白 on `#c1121f` | 6.22:1 | 東急バスのチップ |
| 白 on `#0e7a3d` | 5.43:1 | 川崎市バスのチップ |
| `#8a3418` on `#f6efe2` | 7.10:1 | 警告 |
| `#5c5146` on `#f6efe2` | 6.75:1 | 補足 |

丸ゴシックは `HiraMaruProN-W4`、無ければ `HiraginoMaruGothicProN-W4`、それも無ければ system rounded です。数字は rounded + monospacedDigit です。シミュレータでどの書体が当たったかは、macOS ジョブのスクリーンショットで見てください。

## テスト

```bash
swift test --package-path ios
```

```bash
xcodebuild test \
  -project ios/BusNowApp/BusNow.xcodeproj \
  -scheme BusNow \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

GitHub Actions（`.github/workflows/ios.yml`）は ubuntu-24.04 で `swift test`、macos-15 でシミュレータの `xcodebuild test` とスクリーンショットを取ります。画像はアーティファクト `ios-screenshots` です。このリポジトリを編集した Linux 環境ではシミュレータを起動できないため、`docs/screenshots/` には画像を置いていません。

## 範囲外

ウィジェット、ロック画面、Live Activity、Apple Watch、プッシュ通知、ODPT / GTFS への切り替え、App Store 用のメタデータ、TestFlight へのアップロード。
