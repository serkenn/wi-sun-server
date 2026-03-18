# balenaOS で USB ストレージを使う手順メモ

## 目的
Raspberry Pi 4B 上で、MariaDB や Grafana の永続データ保存による SD カード消耗を避けるため、USB ストレージを常設運用します。

## 前提
- fleet: `Pi-Smarthome`
- device type: `Raspberry Pi 4 (using 64bit OS)`
- USB ストレージは `ext4`
- 容量は DB と Grafana の長期保存に十分あること

## 基本方針
このリポジトリの `docker-compose.yml` は balena の named volume を使います。USB ストレージ利用は、アプリコンテナ内の小細工ではなく Host 側の運用として扱います。

## 実機での確認
Host OS またはホスト OS コンテナから、まず接続状態を確認します。

```sh
lsblk -f
blkid
```

確認したい項目:
- デバイス名
- UUID
- LABEL
- ファイルシステムが `ext4` であること

## 運用ルール
- USB ストレージは抜き差ししない常設運用にする
- デバイス名ではなく UUID または LABEL 基準で扱う
- 再起動後も同じストレージが見えることを確認する
- DB 更新中の抜去を防ぐ

## 推奨手順
1. USB ストレージを `ext4` で初期化する
2. LABEL を付ける。例: `PI4DATA`
3. `lsblk -f` で UUID を記録する
4. balenaOS で再起動し、認識が安定するか確認する
5. 実運用前に MariaDB と Grafana の初回起動後サイズを確認する

## 注意点
- balena のマルチコンテナでは、通常の Docker Compose のように任意ホストパス bind mount 前提で設計しない
- USB 側へ保存先を逃がす設計は Host 側運用と一体で考える
- ログや DB の増加量を見ながら容量監視を行う

## 今後の候補
- hostOS コンテナを追加して USB mount を補助する
- ログ保存量の制御を別途導入する
- バックアップ用の定期エクスポート手順を追加する
