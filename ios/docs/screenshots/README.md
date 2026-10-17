# シミュレータのスクリーンショット

画像はこのディレクトリには置いていません。macOS の GitHub Actions（`.github/workflows/ios.yml` の `macos xcodebuild test`）が、UI テスト通過後に iPhone シミュレータへ BusNow を入れて撮影し、アーティファクト `ios-screenshots` として残します。

撮る画面は、ホーム、富士見台発、溝の口駅南口発、運行終了、片方失敗です。ステータスバーの時刻は 10:30 に固定します。起動引数 `-busnow-scenario` を使うので、公式サイトへは接続しません。

UI テスト自身の画面も `TestResults.xcresult`（アーティファクト `ios-xcresult`）に添付されます。

ローカルで同じ撮影をするとき:

```bash
xcodebuild build \
  -project ios/BusNowApp/BusNow.xcodeproj \
  -scheme BusNow \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath ios/BusNowApp/DerivedData \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO

APP="$(find ios/BusNowApp/DerivedData -path '*iphonesimulator*' -name BusNow.app -type d | head -1)"
UDID="$(xcrun simctl list devices available | awk -F '[()]' '/iPhone 16 / { print $2; exit }')"
bash ios/scripts/capture-screenshots.sh "$APP" /tmp/busnow-screenshots "$UDID"
```
